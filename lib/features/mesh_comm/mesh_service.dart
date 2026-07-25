import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mesh_call_service.dart';
import 'mesh_models.dart';
import 'mesh_transport.dart';
import 'sos_payload.dart';
import 'sos_relay.dart';
import 'sos_relay_listener.dart';
import 'wifi_direct_transport.dart';

const _kServiceId = 'com.shongjog.mesh';

/// Prefix for media (image / video) filename hints sent alongside FILE payloads.
/// Format: `media:<payloadId>:<basename>:<type>` where type is `image` or `video`.
const _kMediaHintPrefix = 'media:';

/// Structured outcome of [MeshService.start].
///
/// `P2P_CLUSTER` is a Wi-Fi Direct / soft-AP strategy on Android — it does
/// NOT use the Bluetooth radio for transport (Bluetooth permissions are only
/// needed so the plugin can advertise/scan beacons). Turning Wi-Fi off
/// therefore prevents peer discovery. [ok] is true only if both advertising
/// and discovery started; [reason] is a short Bangla-safe tag the radar
/// screen can show in a snackbar.
class MeshStartResult {
  final bool ok;
  final bool advertisingOk;
  final bool discoveryOk;
  final bool wifiOn;
  final String? reason;

  const MeshStartResult({
    required this.ok,
    required this.advertisingOk,
    required this.discoveryOk,
    required this.wifiOn,
    this.reason,
  });

  static const success = MeshStartResult(
    ok: true,
    advertisingOk: true,
    discoveryOk: true,
    wifiOn: true,
  );

  static MeshStartResult fail(String reason, {required bool wifiOn}) =>
      MeshStartResult(
        ok: false,
        advertisingOk: false,
        discoveryOk: false,
        wifiOn: wifiOn,
        reason: reason,
      );
}



class MeshService {
  final Strategy strategy = Strategy.P2P_CLUSTER;
  String userName;

  /// Which transport backend is currently active. Null until [start] completes.
  MeshTransportType? activeTransport;

  /// GMS-free fallback transport. Lazily initialized only when GMS is absent.
  WifiDirectTransport? _wifiDirectTransport;
  StreamSubscription? _wdPeerSub;
  StreamSubscription? _wdMsgSub;

  final _peersController = StreamController<List<MeshPeer>>.broadcast();
  final _messagesController = StreamController<MeshMessage>.broadcast();
  final _connectionRequestsController = StreamController<ConnectionRequestEvent>.broadcast();

  final Map<String, MeshPeer> _peers = {};

  // Map to hold files that are currently downloading
  final Map<int, String> _incomingFiles = {};

  /// Timers for cleaning up disconnected peers after a TTL.
  final Map<String, Timer> _disconnectTimers = {};

  /// How long a disconnected peer stays in the list before removal.
  static const _disconnectTtl = Duration(seconds: 30);

  /// Multi-hop SOS relay engine. Wired lazily — the listener is
  /// attached to the messages stream on first [start]().
  SosRelayEngine? _relayEngine;
  SosRelayListener? _relayListener;

  Stream<List<MeshPeer>> get peers => _peersController.stream;
  Stream<MeshMessage> get messages => _messagesController.stream;
  Stream<ConnectionRequestEvent> get connectionRequests => _connectionRequestsController.stream;

  List<MeshPeer> get peerList => _peers.values.toList();
  int get peerCount => _peers.length;

  MeshService._({required this.userName});

  bool _running = false;
  bool get isRunning => _running;

  Future<bool> requestPermissions() async {
    // 🔴 FIX 3: Added nearbyWifiDevices for Android 13+ P2P_CLUSTER
    final statuses = await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();

    return statuses[Permission.bluetoothAdvertise]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted &&
        statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.location]!.isGranted &&
        (statuses[Permission.nearbyWifiDevices] ?? PermissionStatus.granted)
            .isGranted;
    // nearbyWifiDevices may be null on older Androids where the permission
    // doesn't exist — treat missing as granted. On Android 13+ it IS
    // required for P2P_CLUSTER Wi-Fi Direct operations.
  }

  /// Pre-flight check: P2P_CLUSTER needs the Wi-Fi radio.
  /// `connectivity_plus` reports Wi-Fi as a transport, not the radio state,
  /// so we treat any non-airplane "wifi|wifi+cellular" as Wi-Fi on. The
  /// final word comes from startAdvertising/startDiscovery actually
  /// returning true; this check just gives a fast, honest failure message.
  Future<bool> _wifiRadioAvailable() async {
    try {
      final results = await Connectivity().checkConnectivity();
      // Ignore "none" (airplane / radio off). A connected Wi-Fi network is
      // not required — P2P_CLUSTER creates its own group.
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true; // Don't block on a connectivity check failure.
    }
  }

  Future<MeshStartResult> start() async {
    if (_running) return MeshStartResult.success;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name') ?? '';
      if (savedName.isNotEmpty) {
        userName = '$kMeshPeerPrefix$savedName';
      }
    } catch (_) {}

    final granted = await requestPermissions();
    if (!granted) {
      debugPrint('MeshService: permissions denied');
      return MeshStartResult.fail('permissions', wifiOn: true);
    }

    final wifiOn = await _wifiRadioAvailable();
    if (!wifiOn) {
      debugPrint('MeshService: Wi-Fi radio off — cannot start any transport');
      return MeshStartResult.fail('wifi_off', wifiOn: false);
    }

    // ── Dual-Stack Transport Selection ───────────────────────────────────
    // Try Google Nearby first (fastest, peer-symmetric). If advertising
    // AND discovery both fail immediately, GMS is absent → fall back to
    // the GMS-free Wi-Fi Direct transport.
    bool advertisingOk = false;
    bool discoveryOk = false;

    try {
      advertisingOk = await Nearby().startAdvertising(
        userName,
        strategy,
        serviceId: _kServiceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (e) {
      debugPrint('MeshService: Nearby startAdvertising failed: $e');
    }

    try {
      discoveryOk = await Nearby().startDiscovery(
        userName,
        strategy,
        serviceId: _kServiceId,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );
    } catch (e) {
      debugPrint('MeshService: Nearby startDiscovery failed: $e');
    }

    if (advertisingOk || discoveryOk) {
      // Nearby Connections is working → GMS is present.
      activeTransport = MeshTransportType.nearbyConnections;
      debugPrint('MeshService: using Nearby Connections (GMS detected)');
      _running = true;
      _peersController.add(peerList);
      return MeshStartResult(
        ok: true,
        advertisingOk: advertisingOk,
        discoveryOk: discoveryOk,
        wifiOn: wifiOn,
      );
    }

    // ── GMS absent: fall back to GMS-free Wi-Fi Direct ───────────────────
    debugPrint('MeshService: Nearby Connections unavailable → falling back to Wi-Fi Direct');
    final wdt = WifiDirectTransport();
    final wdOk = await wdt.start(userName);
    if (!wdOk) {
      return MeshStartResult.fail('radio_unavailable', wifiOn: wifiOn);
    }

    _wifiDirectTransport = wdt;
    activeTransport = MeshTransportType.wifiDirect;

    // Bridge WifiDirectTransport peers/messages into MeshService streams.
    _wdPeerSub = wdt.peers.listen((peers) {
      _peers.clear();
      for (final p in peers) {
        _peers[p.id] = MeshPeer(
          endpointId: p.id,
          name: p.displayName,
          status: p.isConnected ? PeerStatus.connected : PeerStatus.disconnected,
        );
      }
      _peersController.add(peerList);
    });

    _wdMsgSub = wdt.messages.listen((msg) {
      _messagesController.add(MeshMessage(
        senderId: msg.senderId,
        senderName: msg.senderName,
        text: msg.text,
        type: MessageType.text,
      ));
    });

    _running = true;
    _peersController.add(peerList);
    return MeshStartResult(
      ok: true,
      advertisingOk: true,
      discoveryOk: true,
      wifiOn: wifiOn,
    );
  }

  Future<void> restartDiscovery() async {
    if (!_running) return;
    if (activeTransport == MeshTransportType.wifiDirect) {
      await _wifiDirectTransport?.restartDiscovery();
      return;
    }
    try {
      await Nearby().stopDiscovery();
      await Nearby().startDiscovery(
        userName,
        strategy,
        serviceId: _kServiceId,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: _onEndpointLost,
      );
    } catch (_) {
      // Discovery start is best-effort; a failure here just means no peers
      // are found until the next start attempt.
    }
  }

  Future<void> stop() async {
    _running = false;
    _wdPeerSub?.cancel();
    _wdMsgSub?.cancel();
    if (activeTransport == MeshTransportType.wifiDirect) {
      await _wifiDirectTransport?.stop();
    } else {
      await Nearby().stopAdvertising();
      await Nearby().stopDiscovery();
      await Nearby().stopAllEndpoints();
    }
    for (final t in _disconnectTimers.values) {
      t.cancel();
    }
    _disconnectTimers.clear();
    _peers.clear();
    _incomingFiles.clear();
    _peersController.add(peerList);
  }

  void dispose() {
    _peersController.close();
    _messagesController.close();
  }

  void _onEndpointFound(String id, String name, String serviceId) {
    if (!name.startsWith(kMeshPeerPrefix)) return;

    final existing = _peers[id];
    if (existing != null && existing.status == PeerStatus.connected) return;

    // If this peer was disconnected, cancel its cleanup timer — it's
    // coming back into range. The connection flow will promote it to
    // connected via _onConnectionResult.
    _disconnectTimers.remove(id)?.cancel();

    final displayName = name.substring(kMeshPeerPrefix.length);
    _peers[id] = MeshPeer(
      endpointId: id,
      name: displayName.isNotEmpty ? displayName : id,
      status: PeerStatus.disconnected,
    );
    _peersController.add(peerList);

    // Auto-reconnect if this peer was previously connected or reconnecting
    // (i.e. we had an active session that dropped). This avoids requiring
    // the user to manually tap to reconnect every time discovery finds the
    // peer again.
    if (existing != null &&
        (existing.status == PeerStatus.reconnecting ||
         existing.status == PeerStatus.connected)) {
      connectToEndpoint(id);
    }
  }

  /// Initiate a connection to a discovered peer.
  /// Called when the user taps on a peer in the radar list.
  Future<bool> connectToEndpoint(String endpointId) async {
    try {
      await Nearby().requestConnection(
        userName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      return true;
    } catch (e) {
      debugPrint('MeshService: connectToEndpoint failed: $e');
      return false;
    }
  }

  void _onEndpointLost(String? id) {
    if (id == null) return;
    final peer = _peers[id];
    if (peer == null) return;
    _peers[id] = peer.copyWith(status: PeerStatus.reconnecting);
    _peersController.add(peerList);

    // Start a TTL timer for cleanup if the endpoint doesn't return.
    _disconnectTimers[id]?.cancel();
    _disconnectTimers[id] = Timer(_disconnectTtl, () {
      final p = _peers.remove(id);
      _disconnectTimers.remove(id);
      if (p != null) _peersController.add(peerList);
    });
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    if (info.isIncomingConnection) {
      _connectionRequestsController.add(ConnectionRequestEvent(id, info.endpointName));
    } else {
      acceptConnection(id);
    }
  }

  void acceptConnection(String id) {
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  void rejectConnection(String id) {
    Nearby().rejectConnection(id);
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      _disconnectTimers.remove(id)?.cancel();
      final existing = _peers[id];
      _peers[id] = MeshPeer(
        endpointId: id,
        name: existing?.name ?? id,
        status: PeerStatus.connected,
      );
      _peersController.add(peerList);
    } else {
      _peers.remove(id);
      _disconnectTimers.remove(id)?.cancel();
      _peersController.add(peerList);
    }
  }

  void _onDisconnected(String id) {
    final peer = _peers[id];
    if (peer == null) return;
    // Mark as reconnecting — Nearby may auto-reconnect if the peer
    // comes back into range via onEndpointFound.
    _peers[id] = peer.copyWith(status: PeerStatus.reconnecting);
    _peersController.add(peerList);

    // Start a TTL timer: if the peer doesn't reconnect within
    // [_disconnectTtl], remove it from the map entirely.
    _disconnectTimers[id]?.cancel();
    _disconnectTimers[id] = Timer(_disconnectTtl, () {
      final p = _peers.remove(id);
      _disconnectTimers.remove(id);
      if (p != null) _peersController.add(peerList);
    });
  }

  /// Map of payloadId → basename, populated when the paired bytes hint
  /// arrives before (or after) the FILE payload's SUCCESS callback. The
  /// receiver renames the materialized file with this basename so the
  /// extension matches what the sender recorded.
  final Map<int, String> _incomingFilenames = {};

  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      final bytes = payload.bytes;
      if (bytes == null) return;
      
      final callPrefix = utf8.encode('CALL_AUDIO:');
      if (bytes.length >= callPrefix.length) {
        bool match = true;
        for (int i = 0; i < callPrefix.length; i++) {
          if (bytes[i] != callPrefix[i]) {
            match = false;
            break;
          }
        }
        if (match) {
          final audioData = bytes.sublist(callPrefix.length);
          meshCallService.feedIncomingAudio(audioData);
          return;
        }
      }

      final text = utf8.decode(bytes, allowMalformed: true);
      // Voice filename hint: "voice:<payloadId>:<basename>". Cache the
      // basename for the FILE payload's SUCCESS handler. Non-voice chat
      // bytes that happen to start with "voice:" are ignored safely.
      if (text.startsWith('voice:')) {
        final parts = text.split(':');
        if (parts.length >= 3) {
          final id = int.tryParse(parts[1]);
          if (id != null) _incomingFilenames[id] = parts[2];
        }
        return;
      }
      // Media (image/video) filename hint: "media:<payloadId>:<basename>:<type>"
      if (text.startsWith(_kMediaHintPrefix)) {
        final parts = text.split(':');
        if (parts.length >= 4) {
          final id = int.tryParse(parts[1]);
          if (id != null) {
            // Store basename + type separated by '|'
            _incomingFilenames[id] = '${parts[2]}|${parts[3]}';
          }
        }
        return;
      }
      if (text.startsWith('CALL_SIG:')) {
        meshCallService.handleRawSignal(
          text.substring('CALL_SIG:'.length),
          endpointId,
        );
        return;
      }
      final peerName = _peers[endpointId]?.name ?? endpointId;
      final msg = MeshMessage(
        senderId: endpointId,
        senderName: peerName,
        text: text,
        type: MessageType.text,
      );
      // Run through the relay engine if wired. The listener handles
      // emission back to the controller so we don't double-emit.
      final listener = _relayListener;
      if (listener != null) {
        listener.onIncoming(msg, rawBytes: bytes);
      } else {
        _messagesController.add(msg);
      }
    } else if (payload.type == PayloadType.FILE) {
      // 🔴 FIX 1: Store the file URI, but DO NOT send to UI yet.
      if (payload.uri != null) {
        _incomingFiles[payload.id] = payload.uri!;
      }
    }
  }

  /// Materialize a received FILE payload from a `content://` URI into real
  /// storage. For voice: app-private documents dir. For image/video: also
  /// saved to the device gallery via `gal`.
  Future<_MaterializedFile?> _materializeFile(
      int payloadId, String sourceUri) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final hint = _incomingFilenames.remove(payloadId) ?? '';

      // hint format: "basename" (voice) or "basename|type" (media)
      String basename;
      MessageType msgType;
      if (hint.contains('|')) {
        final parts = hint.split('|');
        basename = parts[0];
        msgType = parts[1] == 'video' ? MessageType.video : MessageType.image;
      } else {
        basename = hint.isNotEmpty ? hint : 'mesh_voice_$payloadId.m4a';
        msgType = MessageType.voice;
      }

      final dest = '${dir.path}/$basename';
      await Nearby().copyFileAndDeleteOriginal(sourceUri, dest);

      // Save images/videos to the device gallery automatically
      if (msgType == MessageType.image || msgType == MessageType.video) {
        try {
          if (msgType == MessageType.image) {
            await Gal.putImage(dest);
          } else {
            await Gal.putVideo(dest);
          }
        } catch (e) {
          debugPrint('MeshService: gallery save failed (non-fatal): $e');
        }
      }

      return _MaterializedFile(dest, msgType);
    } catch (e) {
      debugPrint('MeshService: failed to materialize file: $e');
      _incomingFilenames.remove(payloadId);
      return null;
    }
  }

  // 🔴 FIX 1: Only pass the file to the UI when download completes
  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    if (update.status == PayloadStatus.SUCCESS) {
      final sourceUri = _incomingFiles.remove(update.id);
      if (sourceUri == null) return;
      // Copy the content:// URI into real storage asynchronously; emit the
      // message once the copy completes. If the copy fails we surface a
      // text-fallback so the chat bubble is never a silent dead tap.
      _materializeFile(update.id, sourceUri).then((result) {
        if (result == null) return;
        final peerName = _peers[endpointId]?.name ?? endpointId;
        _messagesController.add(MeshMessage(
          senderId: endpointId,
          senderName: peerName,
          text: '',
          type: result.type,
          filePath: result.path,
        ));
      });
    } else if (update.status == PayloadStatus.FAILURE || update.status == PayloadStatus.CANCELED) {
      _incomingFiles.remove(update.id);
      _incomingFilenames.remove(update.id);
    }
  }

  /// Returns true if at least one peer received the message.
  bool sendMessage(String text, {String? targetEndpointId, bool echoSelf = true}) {
    if (_peers.isEmpty) return false;
    final bytes = Uint8List.fromList(utf8.encode(text));
    var delivered = false;
    for (final peer in _peers.values) {
      if (peer.status == PeerStatus.connected) {
        if (targetEndpointId == null || peer.endpointId == targetEndpointId) {
          try {
            Nearby().sendBytesPayload(peer.endpointId, bytes);
            delivered = true;
          } catch (e) {
            debugPrint('MeshService: sendBytes failed to ${peer.name}: $e');
          }
        }
      }
    }
    // H7 FIX: only add to chat when at least one peer confirmed delivery.
    // Previously the self-bubble was unconditional so the user saw "sent"
    // even when no peers were connected.
    // H8 FIX: use the user's own display name (stripped prefix) instead of
    // the hardcoded English literal 'Me', which violated the Bangla-only UI.
    if (delivered && echoSelf) {
      final selfName = userName.startsWith(kMeshPeerPrefix)
          ? userName.substring(kMeshPeerPrefix.length)
          : userName;
      _messagesController.add(MeshMessage(
        senderId: kMeshSelfId,
        senderName: selfName,
        text: text,
        type: MessageType.text,
      ));
    }
    return delivered;
  }

  /// Lazily wire the SOS relay engine. Idempotent — call from app
  /// startup. Returns the same listener on subsequent calls.
  SosRelayListener ensureRelayEngine() {
    final engine = _relayEngine ??= SosRelayEngine(localDevice: userName);
    return _relayListener ??= SosRelayListener(
      engine: engine,
      sendToAll: (Uint8List bytes) async => sendBytesToAll(bytes),
      emit: _messagesController.add,
    );
  }

  /// Send raw bytes to all connected peers.
  void sendBytesToAll(Uint8List bytes) {
    if (_peers.isEmpty) return;
    for (final peer in _peers.values) {
      try {
        Nearby().sendBytesPayload(peer.endpointId, bytes);
      } catch (e) {
        debugPrint('MeshService: failed to send bytes to ${peer.name}: $e');
      }
    }
  }

  /// Send raw bytes to a specific peer, using the active transport.
  /// H5 FIX: used by MeshCallService for audio chunks so that
  /// GMS-free (WifiDirect) devices don't crash on Nearby().
  void sendBytesToPeer(String endpointId, Uint8List bytes) {
    if (activeTransport == MeshTransportType.wifiDirect) {
      _wifiDirectTransport?.sendBytes(endpointId, bytes);
    } else {
      try {
        Nearby().sendBytesPayload(endpointId, bytes);
      } catch (e) {
        debugPrint('MeshService: sendBytesToPeer failed to $endpointId: $e');
      }
    }
  }

  /// Broadcast a SOS payload over the mesh and add a local copy
  /// to the chat history with hopCount: 0.
  void broadcastSos(SosPayload payload) {
    final encoded = utf8.encode(payload.encode());
    sendBytesToAll(Uint8List.fromList(encoded));
    final selfName = userName.startsWith(kMeshPeerPrefix)
        ? userName.substring(kMeshPeerPrefix.length)
        : userName;
    _messagesController.add(MeshMessage(
      senderId: kMeshSelfId,
      senderName: selfName,
      text: payload.message,
      type: MessageType.text,
      hopCount: 0,
    ));
  }

  /// Send a voice file to connected peers.
  ///
  /// When [targetEndpointId] is null the file is broadcast to every connected
  /// peer; when set, only that peer receives it (used by the per-peer chat).
  ///
  /// The `nearby_connections` plugin stores FILE payloads under
  /// `Downloads/.nearby/` with a generic, extension-less name, so we also
  /// send a paired bytes hint `voice:<payloadId>:<basename>` that the
  /// receiver uses to rename the copied file. `payloadId` is the id that
  /// nearby_connections auto-assigns and returns from `sendFilePayload`,
  /// forwarded into the hint so the receiver's `onPayloadTransferUpdate`
  /// can correlate.
  ///
  /// Returns the persisted file path used for the local chat bubble, or
  /// null if no peers are connected.
  Future<String?> sendVoiceMessage(String filePath,
      {String? targetEndpointId}) async {
    if (_peers.isEmpty) return null;
    final basename = filePath.split('/').last;

    // Persist the recording into app-private storage so it survives the
    // temp-directory cleanup and the sender can replay their own voice.
    String? localPath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = '${dir.path}/$basename';
      final src = File(filePath);
      if (await src.exists()) {
        await src.copy(dest);
        localPath = dest;
      }
    } catch (e) {
      debugPrint('MeshService: failed to persist sender voice: $e');
      localPath = filePath; // Fallback to temp path
    }

    final sendPath = localPath ?? filePath;
    for (final peer in _peers.values) {
      if (peer.status == PeerStatus.connected) {
        if (targetEndpointId == null || peer.endpointId == targetEndpointId) {
          try {
            final filePayloadId =
                Nearby().sendFilePayload(peer.endpointId, sendPath);
            filePayloadId.then((payloadId) {
              final hint = utf8.encode('voice:$payloadId:$basename');
              Nearby().sendBytesPayload(
                peer.endpointId,
                Uint8List.fromList(hint),
              );
            }).catchError((_) {});
          } catch (e) { debugPrint("[Catch] mesh_service: $e"); }
        }
      }
    }
    final selfName = userName.startsWith(kMeshPeerPrefix)
        ? userName.substring(kMeshPeerPrefix.length)
        : userName;
    _messagesController.add(MeshMessage(
      senderId: kMeshSelfId,
      senderName: selfName,
      text: '',
      type: MessageType.voice,
      filePath: sendPath,
    ));
    // Clean up the temp recording after a short delay. The persisted copy
    // in app-private storage is what the sender's bubble points to.
    Timer(const Duration(seconds: 10), () {
      final f = File(filePath);
      if (f.existsSync()) {
        f.delete().catchError((_) => f);
      }
    });
    return sendPath;
  }
  /// Send an image or video file to a peer over the mesh.
  ///
  /// Mirrors [sendVoiceMessage]: sends a FILE payload + a bytes hint
  /// so the receiver can name it correctly and knows whether to treat
  /// it as [MessageType.image] or [MessageType.video].
  /// The received file is automatically saved to the device gallery.
  Future<String?> sendMediaMessage(
    String filePath, {
    required MessageType type,
    String? targetEndpointId,
  }) async {
    assert(type == MessageType.image || type == MessageType.video);
    if (_peers.isEmpty) return null;
    final basename = filePath.split('/').last;
    final typeTag = type == MessageType.video ? 'video' : 'image';

    // Persist into app-private storage so the sender's bubble can display it.
    String? localPath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = '${dir.path}/$basename';
      final src = File(filePath);
      if (await src.exists()) {
        await src.copy(dest);
        localPath = dest;
      }
    } catch (e) {
      debugPrint('MeshService: failed to persist sender media: $e');
      localPath = filePath;
    }

    final sendPath = localPath ?? filePath;
    for (final peer in _peers.values) {
      if (peer.status == PeerStatus.connected) {
        if (targetEndpointId == null || peer.endpointId == targetEndpointId) {
          try {
            final filePayloadId =
                Nearby().sendFilePayload(peer.endpointId, sendPath);
            filePayloadId.then((payloadId) {
              // hint: "media:<id>:<basename>:<type>"
              final hint = utf8.encode(
                  '$_kMediaHintPrefix$payloadId:$basename:$typeTag');
              Nearby().sendBytesPayload(
                peer.endpointId,
                Uint8List.fromList(hint),
              );
            }).catchError((_) {});
          } catch (e) {
            debugPrint('MeshService: sendMediaMessage failed: $e');
          }
        }
      }
    }

    final selfName = userName.startsWith(kMeshPeerPrefix)
        ? userName.substring(kMeshPeerPrefix.length)
        : userName;
    _messagesController.add(MeshMessage(
      senderId: kMeshSelfId,
      senderName: selfName,
      text: '',
      type: type,
      filePath: sendPath,
    ));
    return sendPath;
  }
}

/// Result of materializing a received FILE payload.
class _MaterializedFile {
  final String path;
  final MessageType type;
  const _MaterializedFile(this.path, this.type);
}

final meshService = MeshService._(
  userName: '$kMeshPeerPrefix${Random.secure().nextInt(0x1000000).toRadixString(16).padLeft(6, '0')}',
);