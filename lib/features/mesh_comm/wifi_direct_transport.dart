import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mesh_models.dart';
import 'mesh_transport.dart';

/// GMS-free Wi-Fi Direct transport via flutter_p2p_connection.
///
/// Architecture: one device becomes the "Group Owner" (Host) — it creates a
/// Wi-Fi Direct hotspot. All others are Clients that connect via BLE discovery.
/// The app auto-elects the Host role if no host is found within [_scanTimeout].
///
/// Message format: `<senderId>|<senderName>|<text>` (UTF-8 bytes over the
/// flutter_p2p_connection text channel, matching the Nearby Connections
/// wire format so SosRelayEngine works unchanged).
class WifiDirectTransport implements MeshTransport {
  static const _scanTimeout = Duration(seconds: 12);

  FlutterP2pHost? _host;
  FlutterP2pClient? _client;
  bool _isHost = false;
  bool _running = false;

  // Streams
  final _peersController = StreamController<List<TransportPeer>>.broadcast();
  final _msgController = StreamController<TransportMessage>.broadcast();
  final _reqController = StreamController<ConnectionRequestEvent>.broadcast();

  // Peer tracking
  final Map<String, TransportPeer> _peerMap = {};

  // Subscriptions
  StreamSubscription? _clientListSub;
  StreamSubscription? _textSub;

  @override
  MeshTransportType get type => MeshTransportType.wifiDirect;

  @override
  Stream<List<TransportPeer>> get peers => _peersController.stream;

  @override
  Stream<TransportMessage> get messages => _msgController.stream;

  @override
  Stream<ConnectionRequestEvent> get connectionRequests => _reqController.stream;

  @override
  bool get isRunning => _running;

  String _userName = 'User';
  String _myId = '';

  @override
  Future<bool> start(String userName) async {
    if (_running) return true;
    _userName = userName;

    try {
      final prefs = await SharedPreferences.getInstance();
      _myId = prefs.getString('mesh_device_id') ?? _userName.hashCode.toString();

      // Try to find an existing host first (act as client).
      final clientInst = FlutterP2pClient();
      await clientInst.initialize();

      final foundHost = await _scanForHost(clientInst);

      if (foundHost != null) {
        _client = clientInst;
        _isHost = false;
        await clientInst.connectWithDevice(foundHost);
        _listenAsClient(clientInst);
        debugPrint('WifiDirectTransport: joined as Client');
      } else {
        // No host found — become the host.
        await clientInst.dispose();
        final hostInst = FlutterP2pHost();
        await hostInst.initialize();
        await hostInst.createGroup(advertise: true);
        _host = hostInst;
        _isHost = true;
        _listenAsHost(hostInst);
        debugPrint('WifiDirectTransport: started as Host/Group Owner');
      }

      _running = true;
      return true;
    } catch (e) {
      debugPrint('WifiDirectTransport.start failed: $e');
      return false;
    }
  }

  Future<BleDiscoveredDevice?> _scanForHost(FlutterP2pClient client) async {
    final completer = Completer<BleDiscoveredDevice?>();
    StreamSubscription? sub;

    sub = await client.startScan((devices) {
      for (final d in devices) {
        if (d.deviceName.contains('Shongjog') && !completer.isCompleted) {
          completer.complete(d);
          sub?.cancel();
        }
      }
    });

    Future.delayed(_scanTimeout, () {
      if (!completer.isCompleted) completer.complete(null);
      sub?.cancel();
    });

    return completer.future;
  }

  void _listenAsHost(FlutterP2pHost host) {
    _clientListSub = host.streamClientList().listen((clients) {
      _peerMap.clear();
      for (final c in clients) {
        _peerMap[c.id] = TransportPeer(
          id: c.id,
          displayName: c.username,
          isConnected: true,
        );
      }
      _peersController.add(_peerMap.values.toList());
    });

    _textSub = host.streamReceivedTexts().listen((raw) {
      _handleRawText(raw);
    });
  }

  void _listenAsClient(FlutterP2pClient client) {
    _clientListSub = client.streamClientList().listen((participants) {
      _peerMap.clear();
      for (final p in participants) {
        if (p.id == _myId) continue; // skip self
        _peerMap[p.id] = TransportPeer(
          id: p.id,
          displayName: p.username,
          isConnected: true,
        );
      }
      _peersController.add(_peerMap.values.toList());
    });

    _textSub = client.streamReceivedTexts().listen((raw) {
      _handleRawText(raw);
    });
  }

  void _handleRawText(String raw) {
    // Wire format: `senderId|senderName|text`
    final parts = raw.split('|');
    if (parts.length < 3) return;
    _msgController.add(TransportMessage(
      senderId: parts[0],
      senderName: parts[1],
      text: parts.sublist(2).join('|'),
    ));
  }

  String _encode(String text) => '$_myId|$_userName|$text';

  @override
  bool sendText(String text) {
    final encoded = _encode(text);
    try {
      if (_isHost) {
        _host?.broadcastText(encoded);
      } else {
        _client?.broadcastText(encoded);
      }
      return true;
    } catch (e) {
      debugPrint('WifiDirectTransport.sendText failed: $e');
      return false;
    }
  }

  @override
  bool sendTextToPeer(String peerId, String text) {
    final encoded = _encode(text);
    try {
      if (_isHost) {
        _host?.sendTextToClient(encoded, peerId);
      } else {
        _client?.sendTextToClient(encoded, peerId);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  bool sendFile(String filePath, {String? targetPeerId}) {
    final file = File(filePath);
    try {
      if (_isHost) {
        if (targetPeerId != null) {
          _host?.sendFileToClient(file, targetPeerId);
        } else {
          _host?.broadcastFile(file);
        }
      } else {
        _client?.broadcastFile(file);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Send raw bytes (e.g. PCM audio) to a specific peer.
  /// Encodes as base64 with a 'B64:' prefix so the receiver can
  /// distinguish it from plain text messages.
  void sendBytes(String peerId, Uint8List bytes) {
    final encoded = 'B64:${base64.encode(bytes)}';
    sendTextToPeer(peerId, encoded);
  }

  @override
  void acceptConnection(String peerId) {
    // flutter_p2p_connection auto-accepts; nothing to do here.
  }

  @override
  void rejectConnection(String peerId) {
    // flutter_p2p_connection auto-accepts; nothing to do here.
  }

  @override
  Future<void> restartDiscovery() async {
    if (!_running || _isHost) return;
    // Clients re-scan BLE for new hosts if disconnected.
    debugPrint('WifiDirectTransport: restartDiscovery no-op for client in connected state');
  }

  @override
  Future<void> stop() async {
    _running = false;
    _clientListSub?.cancel();
    _textSub?.cancel();
    try {
      if (_isHost) {
        await _host?.removeGroup();
        await _host?.dispose();
      } else {
        await _client?.disconnect();
        await _client?.dispose();
      }
    } catch (_) {}
    _peerMap.clear();
    _peersController.add([]);
  }

  void dispose() {
    _peersController.close();
    _msgController.close();
    _reqController.close();
  }
}
