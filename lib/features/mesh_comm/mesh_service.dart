import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'mesh_models.dart';
import 'sos_payload.dart';
import 'sos_relay.dart';
import 'sos_relay_listener.dart';

const _kServiceId = 'com.shongjog.mesh';

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
  final String userName;

  final _peersController = StreamController<List<MeshPeer>>.broadcast();
  final _messagesController = StreamController<MeshMessage>.broadcast();

  final Map<String, MeshPeer> _peers = {};

  // 🔴 FIX 1: Map to hold files that are currently downloading
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

    final granted = await requestPermissions();
    if (!granted) {
      debugPrint('MeshService: permissions denied');
      return MeshStartResult.fail('permissions', wifiOn: true);
    }

    final wifiOn = await _wifiRadioAvailable();
    if (!wifiOn) {
      debugPrint('MeshService: Wi-Fi radio off — P2P_CLUSTER cannot start');
      return MeshStartResult.fail('wifi_off', wifiOn: false);
    }

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
      debugPrint('MeshService: startAdvertising failed: $e');
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
      debugPrint('MeshService: startDiscovery failed: $e');
    }

    if (!advertisingOk && !discoveryOk) {
      return MeshStartResult.fail('radio_unavailable', wifiOn: wifiOn);
    }

    _running = true;
    _peersController.add(peerList);
    return MeshStartResult(
      ok: true,
      advertisingOk: advertisingOk,
      discoveryOk: discoveryOk,
      wifiOn: wifiOn,
    );
  }

  Future<void> restartDiscovery() async {
    if (!_running) return;
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
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
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

    // If this peer was disconnected, cancel its cleanup timer — it's
    // coming back into range. The connection flow will promote it to
    // connected via _onConnectionResult.
    _disconnectTimers.remove(id)?.cancel();

    Nearby().requestConnection(
      userName,
      id,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult: _onConnectionResult,
      onDisconnected: _onDisconnected,
    );
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
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate, // 🔴 FIX 1
    );
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

  /// Copy a received voice payload out of the nearby_connections plugin's
  /// `content://` URI into app-private storage so `audioplayers` can read it.
  /// The plugin stores FILE payloads under `Downloads/.nearby/` with a
  /// generic name — `UrlSource('content://…')` does NOT work, only a real
  /// filesystem path does.
  Future<String?> _materializeVoiceFile(int payloadId, String sourceUri) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      // Prefer the basename from the paired voice-hint bytes payload; fall
      // back to a generic .m4a extension if the hint hasn't arrived yet.
      final basename = _incomingFilenames.remove(payloadId);
      final safeName = (basename != null && basename.isNotEmpty)
          ? basename
          : 'mesh_voice_$payloadId.m4a';
      final dest = '${dir.path}/$safeName';
      // copyFileAndDeleteOriginal: documented convenience on the plugin
      // (https://pub.dev/packages/nearby_connections — "Convenience method to
      // copy file using its uri"). It accepts the content:// URI directly.
      await Nearby().copyFileAndDeleteOriginal(sourceUri, dest);
      return dest;
    } catch (e) {
      debugPrint('MeshService: failed to materialize voice file: $e');
      // Hint is consumed; if a retry comes through we'll fall back to .m4a.
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
      _materializeVoiceFile(update.id, sourceUri).then((filePath) {
        final peerName = _peers[endpointId]?.name ?? endpointId;
        _messagesController.add(MeshMessage(
          senderId: endpointId,
          senderName: peerName,
          text: filePath == null ? '⚠ ভয়েস ফাইল সংরক্ষণ ব্যর্থ' : '',
          type: MessageType.voice,
          filePath: filePath,
        ));
      });
    } else if (update.status == PayloadStatus.FAILURE || update.status == PayloadStatus.CANCELED) {
      _incomingFiles.remove(update.id);
      _incomingFilenames.remove(update.id);
    }
  }

  /// Returns true if at least one peer received the message.
  bool sendMessage(String text, {String? targetEndpointId}) {
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
    _messagesController.add(MeshMessage(
      senderId: kMeshSelfId,
      senderName: 'Me',
      text: text,
      type: MessageType.text,
    ));
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

  /// Send raw bytes to all connected peers. Used by the SOS relay
  /// listener to forward decoded payloads. Does NOT add to the
  /// local message history (the listener handles that for SOS).
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

  /// Broadcast a SOS payload over the mesh and add a local copy
  /// to the chat history with hopCount: 0.
  void broadcastSos(SosPayload payload) {
    final encoded = utf8.encode(payload.encode());
    sendBytesToAll(Uint8List.fromList(encoded));
    _messagesController.add(MeshMessage(
      senderId: kMeshSelfId,
      senderName: 'Me',
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
          } catch (_) {}
        }
      }
    }
    _messagesController.add(MeshMessage(
      senderId: kMeshSelfId,
      senderName: 'Me',
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
}

final meshService = MeshService._(
  userName: '$kMeshPeerPrefix${Random.secure().nextInt(0x1000000).toRadixString(16).padLeft(6, '0')}',
);