import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mesh_models.dart';
import 'mesh_service.dart';

/// Represents a peer discovered over the local LAN or personal mobile hotspot.
class LanPeer {
  final String id;
  final String name;
  final InternetAddress address;
  final int port;
  final DateTime lastSeen;
  bool isConnected;

  LanPeer({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    required this.lastSeen,
    this.isConnected = false,
  });

  MeshPeer toMeshPeer() {
    return MeshPeer(
      endpointId: 'lan_${address.address}_$port',
      name: name,
      status: isConnected ? PeerStatus.connected : PeerStatus.disconnected,
      lastSeen: lastSeen,
    );
  }
}

/// Tier 1 Local Wi-Fi / Hotspot Transport.
///
/// Implements the Briar `LanTcpPlugin` pattern:
/// - When devices share a Wi-Fi router OR one phone runs a Portable Hotspot,
///   all communication flows directly through standard Dart TCP [ServerSocket]
///   and [Socket] connections.
/// - Completely independent of Google Play Services and Android's `WifiP2pManager`.
/// - 0% risk of Wi-Fi Direct zombie radio locks or vendor power-management kills.
/// - UDP subnet broadcast on port 53535 delivers sub-second discovery (< 300ms).
class LanSocketTransport {
  static const int kDiscoveryPort = 53535;
  static const Duration kBeaconInterval = Duration(seconds: 3);
  static const Duration kPeerTtl = Duration(seconds: 12);

  String userName;
  late String _myId;
  int _tcpPort = 0;

  ServerSocket? _serverSocket;
  RawDatagramSocket? _udpSocket;
  Timer? _beaconTimer;
  Timer? _cleanupTimer;

  bool _running = false;
  bool get isRunning => _running;

  final Map<String, LanPeer> _discoveredPeers = {};
  final Map<String, Socket> _activeSockets = {}; // endpointId -> socket

  final _peersController = StreamController<List<MeshPeer>>.broadcast();
  final _messagesController = StreamController<MeshMessage>.broadcast();
  final _requestsController = StreamController<ConnectionRequestEvent>.broadcast();
  final _progressController = StreamController<FileTransferProgress>.broadcast();

  Stream<List<MeshPeer>> get peers => _peersController.stream;
  Stream<MeshMessage> get messages => _messagesController.stream;
  Stream<ConnectionRequestEvent> get connectionRequests => _requestsController.stream;
  Stream<FileTransferProgress> get transferProgress => _progressController.stream;

  List<MeshPeer> get peerList =>
      _discoveredPeers.values.map((p) => p.toMeshPeer()).toList();

  LanSocketTransport({required this.userName});

  void updateUserName(String newName) {
    userName = newName;
    broadcastBeacon();
  }

  Future<bool> start() async {
    if (_running) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _myId = prefs.getString('mesh_device_id') ?? '';
      if (_myId.isEmpty) {
        _myId = '${userName.hashCode.abs()}_${DateTime.now().millisecondsSinceEpoch % 10000}';
        await prefs.setString('mesh_device_id', _myId);
      }

      // 1. Start TCP ServerSocket on ephemeral port
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      _tcpPort = _serverSocket!.port;
      _serverSocket!.listen(_handleIncomingClient, onError: (e) {
        debugPrint('LanSocketTransport: ServerSocket error: $e');
      });

      // 2. Start UDP Broadcast Socket for discovery
      try {
        _udpSocket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          kDiscoveryPort,
          reuseAddress: true,
          reusePort: false,
        );
        _udpSocket!.broadcastEnabled = true;
        _udpSocket!.listen(_handleUdpPacket);
      } catch (e) {
        debugPrint('LanSocketTransport: UDP bind warning: $e');
      }

      _running = true;

      // 3. Start Periodic Beacon Broadcast
      _beaconTimer = Timer.periodic(kBeaconInterval, (_) => broadcastBeacon());
      broadcastBeacon(); // Kick immediate first beacon

      // 4. Start Peer TTL Cleanup
      _cleanupTimer = Timer.periodic(const Duration(seconds: 4), (_) => _cleanupStalePeers());

      debugPrint('LanSocketTransport: Started on TCP port $_tcpPort, UDP port $kDiscoveryPort');
      return true;
    } catch (e) {
      debugPrint('LanSocketTransport: start failed: $e');
      await stop();
      return false;
    }
  }

  Future<void> stop() async {
    _running = false;
    _beaconTimer?.cancel();
    _cleanupTimer?.cancel();

    for (final s in _activeSockets.values) {
      try {
        s.destroy();
      } catch (_) {}
    }
    _activeSockets.clear();

    try {
      await _serverSocket?.close();
    } catch (_) {}
    _serverSocket = null;

    try {
      _udpSocket?.close();
    } catch (_) {}
    _udpSocket = null;

    _discoveredPeers.clear();
    if (!_peersController.isClosed) {
      _peersController.add([]);
    }
  }

  /// Broadcast discovery beacon to the local network subnet
  Future<void> broadcastBeacon() async {
    if (!_running || _udpSocket == null || _tcpPort == 0) return;

    final beacon = jsonEncode({
      'v': 1,
      'type': 'beacon',
      'id': _myId,
      'name': userName,
      'port': _tcpPort,
    });
    final bytes = utf8.encode(beacon);

    try {
      // Broadcast to standard IPv4 subnet broadcast
      _udpSocket?.send(bytes, InternetAddress('255.255.255.255'), kDiscoveryPort);

      // Also send specifically to standard Android Wi-Fi hotspot gateways (192.168.43.1 / 255)
      _udpSocket?.send(bytes, InternetAddress('192.168.43.255'), kDiscoveryPort);
      _udpSocket?.send(bytes, InternetAddress('192.168.49.255'), kDiscoveryPort);
    } catch (_) {}
  }

  void _handleUdpPacket(RawSocketEvent event) {
    if (event != RawSocketEvent.read || _udpSocket == null) return;
    try {
      final datagram = _udpSocket!.receive();
      if (datagram == null) return;

      final str = utf8.decode(datagram.data);
      final json = jsonDecode(str) as Map<String, dynamic>;
      final peerId = json['id'] as String?;
      final peerName = json['name'] as String?;
      final port = json['port'] as int?;
      final type = json['type'] as String?;

      if (peerId == null || peerId == _myId || peerName == userName || port == null || peerName == null) {
        return; // Ignore self or malformed packet
      }

      final senderIp = datagram.address;
      final endpointId = 'lan_${senderIp.address}_$port';
      final existing = _discoveredPeers[endpointId];

      // If the device already exists under a different endpoint ID (e.g. port or IP changed), remove the stale entry
      _discoveredPeers.removeWhere((k, v) => v.id == peerId && k != endpointId);

      _discoveredPeers[endpointId] = LanPeer(
        id: peerId,
        name: peerName,
        address: senderIp,
        port: port,
        lastSeen: DateTime.now(),
        isConnected: existing?.isConnected ?? false,
      );

      final bool isNewOrChanged = existing == null ||
          existing.name != peerName ||
          existing.port != port ||
          existing.id != peerId;

      if (isNewOrChanged) {
        _peersController.add(peerList);
      }

      // If it was a beacon, reply with a direct unicast pong so the peer discovers us immediately
      if (type == 'beacon') {
        final reply = jsonEncode({
          'v': 1,
          'type': 'pong',
          'id': _myId,
          'name': userName,
          'port': _tcpPort,
        });
        _udpSocket?.send(utf8.encode(reply), senderIp, kDiscoveryPort);
      }
    } catch (_) {}
  }

  void _cleanupStalePeers() {
    if (!_running) return;
    final now = DateTime.now();
    bool changed = false;

    _discoveredPeers.removeWhere((id, peer) {
      if (now.difference(peer.lastSeen) > kPeerTtl && !peer.isConnected) {
        changed = true;
        return true;
      }
      return false;
    });

    if (changed) {
      _peersController.add(peerList);
    }
  }

  /// Handles incoming TCP connection from another peer
  void _handleIncomingClient(Socket socket) {
    final remoteAddress = socket.remoteAddress.address;
    final remotePort = socket.remotePort;
    debugPrint('LanSocketTransport: Incoming connection from $remoteAddress:$remotePort');

    String? associatedEndpointId;

    // Buffer to handle length-prefixed framing
    final buffer = <int>[];

    socket.listen(
      (data) {
        buffer.addAll(data);
        _processFramedMessages(buffer, (msgJson) {
          final type = msgJson['type'] as String?;
          final senderId = msgJson['senderId'] as String?;
          final senderName = msgJson['senderName'] as String?;

          if (type == 'connect_request') {
            final peerTcpPort = msgJson['serverPort'] as int? ?? remotePort;
            associatedEndpointId = 'lan_${remoteAddress}_$peerTcpPort';
            _activeSockets[associatedEndpointId!] = socket;

            _requestsController.add(
              ConnectionRequestEvent(associatedEndpointId!, senderName ?? 'LAN Peer'),
            );
          } else if (type == 'ping') {
            _sendFrame(socket, {'type': 'pong'});
          } else if (type == 'pong') {
            // Keep-alive heartbeat ack, ignore
          } else if (type == 'text') {
            final text = msgJson['text'] as String? ?? '';
            if (text == 'PING' || text == 'PONG') return;
            final msg = MeshMessage(
              senderId: associatedEndpointId ?? senderId ?? remoteAddress,
              senderName: senderName ?? 'LAN Peer',
              text: text,
              type: MessageType.text,
            );
            _messagesController.add(msg);
          } else if (type == 'file_payload') {
            _handleReceivedFilePayload(msgJson, associatedEndpointId ?? remoteAddress);
          }
        });
      },
      onDone: () {
        if (associatedEndpointId != null) {
          _activeSockets.remove(associatedEndpointId);
          if (_discoveredPeers.containsKey(associatedEndpointId)) {
            _discoveredPeers[associatedEndpointId!]!.isConnected = false;
            _peersController.add(peerList);
          }
        }
        socket.destroy();
      },
      onError: (e) {
        debugPrint('LanSocketTransport: Socket error: $e');
        if (associatedEndpointId != null) {
          _activeSockets.remove(associatedEndpointId);
          if (_discoveredPeers.containsKey(associatedEndpointId)) {
            _discoveredPeers[associatedEndpointId!]!.isConnected = false;
            _peersController.add(peerList);
          }
        }
        socket.destroy();
      },
    );
  }

  /// Decode length-prefixed frames: [4 bytes length uint32 big-endian][UTF-8 JSON string]
  void _processFramedMessages(List<int> buffer, void Function(Map<String, dynamic>) onMessage) {
    while (buffer.length >= 4) {
      final byteData = ByteData.sublistView(Uint8List.fromList(buffer.sublist(0, 4)));
      final frameLen = byteData.getUint32(0, Endian.big);

      if (buffer.length < 4 + frameLen) {
        break; // Wait for full frame
      }

      final payloadBytes = buffer.sublist(4, 4 + frameLen);
      buffer.removeRange(0, 4 + frameLen);

      try {
        final jsonStr = utf8.decode(payloadBytes);
        final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
        onMessage(jsonMap);
      } catch (e) {
        debugPrint('LanSocketTransport: frame decode error: $e');
      }
    }
  }

  /// Sends a length-prefixed frame to a socket
  void _sendFrame(Socket socket, Map<String, dynamic> msg) {
    try {
      final jsonBytes = utf8.encode(jsonEncode(msg));
      final frame = BytesBuilder(copy: false);
      final lenBytes = ByteData(4)..setUint32(0, jsonBytes.length, Endian.big);
      frame.add(lenBytes.buffer.asUint8List());
      frame.add(jsonBytes);
      socket.add(frame.toBytes());
    } catch (e) {
      debugPrint('LanSocketTransport: _sendFrame error: $e');
    }
  }

  /// Connect to a discovered LAN peer and await confirmation
  Future<bool> connectToPeer(String endpointId) async {
    final peer = _discoveredPeers[endpointId];
    if (peer == null) return false;

    try {
      final socket = await Socket.connect(
        peer.address,
        peer.port,
        timeout: const Duration(seconds: 5),
      );

      _activeSockets[endpointId] = socket;
      final completer = Completer<bool>();

      // Send connection request frame to prompt the receiver
      _sendFrame(socket, {
        'type': 'connect_request',
        'senderId': _myId,
        'senderName': userName,
        'serverPort': _tcpPort,
      });

      // Listen for incoming frames on this client socket
      final buffer = <int>[];
      socket.listen(
        (data) {
          buffer.addAll(data);
          _processFramedMessages(buffer, (msgJson) {
            final type = msgJson['type'] as String?;
            final senderName = msgJson['senderName'] as String?;

            if (type == 'connect_accept') {
              peer.isConnected = true;
              _peersController.add(peerList);
              if (!completer.isCompleted) completer.complete(true);
            } else if (type == 'connect_reject') {
              peer.isConnected = false;
              _peersController.add(peerList);
              _activeSockets.remove(endpointId);
              socket.destroy();
              if (!completer.isCompleted) completer.complete(false);
            } else if (type == 'ping') {
              _sendFrame(socket, {'type': 'pong'});
            } else if (type == 'pong') {
              // Keep-alive heartbeat ack, ignore
            } else if (type == 'text') {
              final text = msgJson['text'] as String? ?? '';
              if (text == 'PING' || text == 'PONG') return;
              _messagesController.add(MeshMessage(
                senderId: endpointId,
                senderName: senderName ?? peer.name,
                text: text,
                type: MessageType.text,
              ));
            } else if (type == 'file_payload') {
              _handleReceivedFilePayload(msgJson, endpointId);
            }
          });
        },
        onDone: () {
          _activeSockets.remove(endpointId);
          peer.isConnected = false;
          _peersController.add(peerList);
          socket.destroy();
          if (!completer.isCompleted) completer.complete(false);
        },
        onError: (_) {
          _activeSockets.remove(endpointId);
          peer.isConnected = false;
          _peersController.add(peerList);
          socket.destroy();
          if (!completer.isCompleted) completer.complete(false);
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (!completer.isCompleted) completer.complete(false);
          _activeSockets.remove(endpointId);
          peer.isConnected = false;
          _peersController.add(peerList);
          socket.destroy();
          return false;
        },
      );
    } catch (e) {
      debugPrint('LanSocketTransport: connectToPeer failed: $e');
      return false;
    }
  }

  /// Send text message over LAN socket
  bool sendText(String endpointId, String text) {
    final socket = _activeSockets[endpointId];
    if (socket == null) return false;

    if (text == 'PING') {
      _sendFrame(socket, {'type': 'ping'});
      return true;
    }
    if (text == 'PONG') {
      _sendFrame(socket, {'type': 'pong'});
      return true;
    }

    _sendFrame(socket, {
      'type': 'text',
      'senderId': _myId,
      'senderName': userName,
      'text': text,
    });
    return true;
  }

  /// Send file / media over LAN socket
  Future<bool> sendFile(
    String endpointId,
    String filePath, {
    required MessageType type,
  }) async {
    final socket = _activeSockets[endpointId];
    if (socket == null) return false;

    final file = File(filePath);
    if (!file.existsSync()) return false;

    try {
      final fileName = filePath.split(RegExp(r'[/\\]')).last;
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);

      _sendFrame(socket, {
        'type': 'file_payload',
        'senderId': _myId,
        'senderName': userName,
        'fileName': fileName,
        'msgType': type.name,
        'data': base64Str,
      });

      return true;
    } catch (e) {
      debugPrint('LanSocketTransport: sendFile failed: $e');
      return false;
    }
  }

  /// Handle incoming file / media payload over LAN socket
  Future<void> _handleReceivedFilePayload(
    Map<String, dynamic> msgJson,
    String endpointId,
  ) async {
    try {
      final fileName = msgJson['fileName'] as String? ?? 'file.bin';
      final msgTypeName = msgJson['msgType'] as String? ?? 'file';
      final base64Data = msgJson['data'] as String? ?? '';
      final senderName = msgJson['senderName'] as String? ?? 'LAN Peer';

      if (base64Data.isEmpty) return;
      final fileBytes = base64Decode(base64Data);

      // Save into app documents directory or configured custom directory
      final prefs = await SharedPreferences.getInstance();
      final customDir = prefs.getString('pref_mesh_storage_dir');

      Directory saveDir;
      if (customDir != null && Directory(customDir).existsSync()) {
        saveDir = Directory(customDir);
      } else {
        saveDir = await Directory.systemTemp.createTemp('lan_recv_');
      }

      final savePath = '${saveDir.path}/$fileName';
      final savedFile = File(savePath);
      await savedFile.writeAsBytes(fileBytes);

      MessageType type = MessageType.file;
      if (msgTypeName == 'image') type = MessageType.image;
      if (msgTypeName == 'video') type = MessageType.video;
      if (msgTypeName == 'voice') type = MessageType.voice;

      _messagesController.add(MeshMessage(
        senderId: endpointId,
        senderName: senderName,
        text: type == MessageType.file ? fileName : '',
        type: type,
        filePath: savePath,
      ));
    } catch (e) {
      debugPrint('LanSocketTransport: _handleReceivedFilePayload error: $e');
    }
  }

  void acceptConnection(String endpointId) {
    final socket = _activeSockets[endpointId];
    if (socket != null) {
      _sendFrame(socket, {
        'type': 'connect_accept',
        'senderId': _myId,
        'senderName': userName,
      });
    }
    if (_discoveredPeers.containsKey(endpointId)) {
      _discoveredPeers[endpointId]!.isConnected = true;
      _peersController.add(peerList);
    }
  }

  void rejectConnection(String endpointId) {
    final socket = _activeSockets.remove(endpointId);
    if (socket != null) {
      try {
        _sendFrame(socket, {
          'type': 'connect_reject',
        });
      } catch (_) {}
      socket.destroy();
    }
    if (_discoveredPeers.containsKey(endpointId)) {
      _discoveredPeers[endpointId]!.isConnected = false;
      _peersController.add(peerList);
    }
  }
}
