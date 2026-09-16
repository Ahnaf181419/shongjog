import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mesh_call_service.dart';
import 'mesh_models.dart';
import 'mesh_transport.dart';
import '../safe_beacon/safety_status_service.dart';
import 'sos_payload.dart';
import 'sos_relay.dart';
import 'sos_relay_listener.dart';
import 'lan_socket_transport.dart';
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

  /// Tier 1: Local LAN & Hotspot Socket Transport (Briar LanTcpPlugin pattern).
  LanSocketTransport? _lanTransport;
  StreamSubscription? _lanPeerSub;
  StreamSubscription? _lanMsgSub;
  StreamSubscription? _lanReqSub;
  StreamSubscription? _lanProgSub;

  final _peersController = StreamController<List<MeshPeer>>.broadcast();
  final _messagesController = StreamController<MeshMessage>.broadcast();
  final _connectionRequestsController = StreamController<ConnectionRequestEvent>.broadcast();

  final Map<String, MeshPeer> _peers = {};

  // Map to hold files that are currently downloading
  final Map<int, String> _incomingFiles = {};

  /// Set of payload IDs that are voice clips — excluded from file transfer progress UI.
  final Set<int> _voicePayloadIds = {};

  /// Timers for cleaning up disconnected peers after a TTL.
  final Map<String, Timer> _disconnectTimers = {};

  /// Names learned during connection initiation, used as fallback in
  /// [_onConnectionResult] when no prior discovery provided a name.
  final Map<String, String> _pendingConnectionNames = {};

  /// How long a disconnected peer stays in the list before removal.
  static const _disconnectTtl = Duration(seconds: 30);

  /// App-wide periodic timer that keeps discovery alive regardless of which
  /// screen is active. Previously this lived only in MeshRadarScreen and died
  /// when the user navigated away, breaking peer discovery for both devices.
  Timer? _discoveryTimer;
  static const _discoveryInterval = Duration(seconds: 15);

  /// 🔴 FIX 8.5: Message retry queue for offline/reconnecting peers.
  final List<_QueuedMessage> _retryQueue = [];
  Timer? _retryTimer;

  /// 🔴 FIX 8.6: Smart discovery throttling state.
  int _emptyDiscoveryTicks = 0;
  DateTime? _lastRestartDiscoveryTime;
  DateTime? _lastRestartAdvertisingTime;

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
    int sdkInt = 33;
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        sdkInt = androidInfo.version.sdkInt;
      } catch (_) {}
    }

    // Android 11 (API 30) and below only support & require runtime Location.
    // Bluetooth permissions (BLUETOOTH, BLUETOOTH_ADMIN) are granted at install time.
    final reqList = <Permission>[Permission.location];

    // Android 12 (API 31) added granular Bluetooth runtime permissions
    if (sdkInt >= 31) {
      reqList.addAll([
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ]);
    }

    // Android 13 (API 33) added NEARBY_WIFI_DEVICES for Wi-Fi Direct
    if (sdkInt >= 33) {
      reqList.add(Permission.nearbyWifiDevices);
    }

    final statuses = await reqList.request();

    // Location is mandatory on all Android versions for Wi-Fi Direct & Bluetooth discovery
    final locGranted = statuses[Permission.location]?.isGranted ?? false;
    if (!locGranted) {
      debugPrint('MeshService: location permission not granted');
      return false;
    }

    if (sdkInt >= 31) {
      final btAdv = statuses[Permission.bluetoothAdvertise]?.isGranted ?? false;
      final btConn = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final btScan = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      if (!btAdv || !btConn || !btScan) {
        debugPrint('MeshService: Android 12+ Bluetooth permissions not granted');
        return false;
      }
    }

    if (sdkInt >= 33) {
      final nearbyWifi = statuses[Permission.nearbyWifiDevices]?.isGranted ?? true;
      if (!nearbyWifi) {
        debugPrint('MeshService: Android 13+ nearbyWifiDevices not granted');
        return false;
      }
    }

    return true;
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
    if (_running) {
      if (!hasLiveLink) {
        ensureDiscoverable(force: false);
      }
      _peersController.add(peerList);
      return MeshStartResult.success;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name') ?? '';
      if (savedName.isNotEmpty) {
        userName = '$kMeshPeerPrefix$savedName';
      }
    } catch (_) {}

    // ── Tier 1: Local LAN & Hotspot Socket Transport (Briar LanTcpPlugin pattern) ──
    try {
      _lanTransport = LanSocketTransport(userName: userName);
      final lanOk = await _lanTransport!.start();
      if (lanOk) {
        _lanPeerSub = _lanTransport!.peers.listen((lanPeers) {
          bool changed = false;
          final incomingLanIds = lanPeers.map((p) => p.endpointId).toSet();
          
          // Remove stale LAN peers that disappeared from the LAN stream
          final staleLanIds = _peers.keys
              .where((k) => k.startsWith('lan_') && !incomingLanIds.contains(k))
              .toList();
          
          for (final id in staleLanIds) {
            _disconnectTimers.remove(id)?.cancel();
            _peers.remove(id);
            changed = true;
          }

          for (final lp in lanPeers) {
            if (_upsertPeer(lp)) {
              changed = true;
            }
          }
          if (changed) {
            _peersController.add(peerList);
          }
        });

        _lanMsgSub = _lanTransport!.messages.listen((msg) {
          if (_isUserMessage(msg.text)) {
            _messagesController.add(msg);
          }
        });

        _lanReqSub = _lanTransport!.connectionRequests.listen((req) {
          final existing = _peers[req.endpointId];
          if (existing != null) {
            _peers[req.endpointId] = existing.copyWith(status: PeerStatus.reconnecting);
            _peersController.add(peerList);
          }
          _connectionRequestsController.add(req);
        });

        _lanProgSub = _lanTransport!.transferProgress.listen((p) {
          _transferProgressController.add(p);
        });
      }
    } catch (e) {
      debugPrint('MeshService: LanSocketTransport startup warning: $e');
    }

    final granted = await requestPermissions();
    if (!granted) {
      debugPrint('MeshService: permissions denied');
      return MeshStartResult.fail('permissions', wifiOn: true);
    }

    final wifiOn = await _wifiRadioAvailable();
    if (!wifiOn) {
      debugPrint('MeshService: Wi-Fi radio off — proceeding with Bluetooth-only transport');
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
      _startDiscoveryTimer();
      _startRetryTimer();
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
    _startDiscoveryTimer();
    _startRetryTimer();
    _peersController.add(peerList);
    return MeshStartResult(
      ok: true,
      advertisingOk: true,
      discoveryOk: true,
      wifiOn: wifiOn,
    );
  }

  /// True while any peer is connected or mid-reconnect — i.e. while the
  /// radio is carrying, or actively re-establishing, a real link.
  ///
  /// Every path that would restart discovery or advertising consults this
  /// first; see [_startDiscoveryTimer] for why bouncing the radio under a
  /// live link is what made mesh chat unstable.
  bool get hasLiveLink =>
      _peers.values.any((p) => p.status != PeerStatus.disconnected);

  /// Seed the peer map so [hasLiveLink] can be exercised without radios.
  @visibleForTesting
  void debugSeedPeers(List<MeshPeer> peers) {
    _peers
      ..clear()
      ..addEntries(peers.map((p) => MapEntry(p.endpointId, p)));
  }

  /// Start the app-wide discovery refresh timer. Idempotent — cancels any
  /// existing timer before creating a new one.
  ///
  /// **The refresh only runs while there is nothing to protect.** This timer
  /// exists to recover from a scan that has gone quiet without finding
  /// anyone; it used to fire unconditionally, so every 15 seconds — *even
  /// with peers connected* — it called `stopDiscovery()`/`startDiscovery()`
  /// and `stopAdvertising()`/`startAdvertising()`.
  ///
  /// On `P2P_CLUSTER` those are not passive scans: the strategy negotiates a
  /// Wi-Fi Direct / soft-AP group, and tearing advertising or discovery down
  /// disturbs that negotiation underneath a live connection. The result was a
  /// link that established fine and then destabilized on a 15-second
  /// cadence — dropped peers, stalled payloads, chat that "connects but
  /// isn't stable" — with the cause invisible because each individual
  /// restart is best-effort and swallows its own errors.
  ///
  /// Once a peer is connected the app no longer needs to hunt for it, so the
  /// refresh stands down and leaves the radio alone. Discovery and
  /// advertising both remain *running* from [start] — this only stops the
  /// periodic bounce. When the last peer drops, [hasLiveLink] goes false and
  /// the refresh resumes on the next tick.
  void _startDiscoveryTimer() {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(_discoveryInterval, (_) {
      if (!_running) return;
      if (hasLiveLink) {
        _emptyDiscoveryTicks = 0;
        // Heartbeat: keep sockets open & alive across both radios
        for (final p in _peers.values) {
          if (p.status == PeerStatus.connected) {
            sendMessage('PING', targetEndpointId: p.endpointId, echoSelf: false, enqueueOnFailure: false);
          }
        }
        return;
      }

      // 🔴 FIX 8.6: Smart discovery throttling when alone
      if (_peers.isEmpty) {
        _emptyDiscoveryTicks++;
        // Throttle: skip ticks to extend interval from 15s -> 30s -> 60s
        if (_emptyDiscoveryTicks > 8 && _emptyDiscoveryTicks % 4 != 0) {
          return; // 60s cadence
        } else if (_emptyDiscoveryTicks > 4 && _emptyDiscoveryTicks % 2 != 0) {
          return; // 30s cadence
        }
      } else {
        _emptyDiscoveryTicks = 0;
      }

      restartDiscovery();
      restartAdvertising();
    });
  }

  Future<void> restartDiscovery({bool force = false}) async {
    if (!_running) return;
    final now = DateTime.now();
    // 🔴 FIX 8.6: Debounce rapid consecutive calls unless forced
    if (!force && _lastRestartDiscoveryTime != null) {
      if (now.difference(_lastRestartDiscoveryTime!) < const Duration(seconds: 2)) {
        return;
      }
    }
    _lastRestartDiscoveryTime = now;
    _emptyDiscoveryTicks = 0;

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

  /// Restart advertising so the username is always broadcast to nearby peers.
  /// If advertising was dropped by the OS, this re-establishes it.
  Future<void> restartAdvertising({bool force = false}) async {
    if (!_running) return;
    final now = DateTime.now();
    if (!force && _lastRestartAdvertisingTime != null) {
      if (now.difference(_lastRestartAdvertisingTime!) < const Duration(seconds: 2)) {
        return;
      }
    }
    _lastRestartAdvertisingTime = now;

    if (activeTransport == MeshTransportType.wifiDirect) return;
    try {
      await Nearby().stopAdvertising();
      await Nearby().startAdvertising(
        userName,
        strategy,
        serviceId: _kServiceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
    } catch (_) {
      // Advertising restart is best-effort.
    }
  }

  /// Forces both advertising (so others can discover this device) and
  /// discovery (so this device finds others) to be active.
  ///
  /// Safe to call on screen entry or navigation return.
  Future<void> ensureDiscoverable({bool force = false}) async {
    if (!_running) {
      await start();
      return;
    }
    if (hasLiveLink && !force) {
      // Live link is active! DO NOT tear down or bounce advertising/discovery!
      // Doing so causes Android WifiP2pManager to enter zombie/BUSY state.
      _lanTransport?.broadcastBeacon();
      return;
    }
    await restartAdvertising(force: force);
    if (!hasLiveLink || force) {
      await restartDiscovery(force: force);
    }
    _lanTransport?.broadcastBeacon();
  }

  /// 🔴 FIX 8.5: Background timer to flush pending message retry queue.
  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_running || _retryQueue.isEmpty) return;
      _flushRetryQueue();
    });
  }

  /// Flush pending queued messages for connected peers.
  void _flushRetryQueue({String? targetEndpointId}) {
    if (_retryQueue.isEmpty) return;
    final now = DateTime.now();
    _retryQueue.removeWhere((q) {
      if (now.difference(q.createdAt) > const Duration(seconds: 25)) return true;
      if (q.retries >= 3) return true;
      if (targetEndpointId != null && q.targetEndpointId != targetEndpointId) {
        return false;
      }
      final peer = _peers[q.targetEndpointId];
      if (peer != null && peer.status == PeerStatus.connected) {
        q.retries++;
        final ok = sendMessage(
          q.text,
          targetEndpointId: q.targetEndpointId,
          echoSelf: false,
          enqueueOnFailure: false,
        );
        return ok;
      }
      return false;
    });
  }

  /// Update the local user's profile display name, re-advertise if idle,
  /// and announce to any connected peers over the live link.
  Future<void> updateUserName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    userName = '$kMeshPeerPrefix$trimmed';
    if (_running) {
      if (!hasLiveLink) {
        await restartAdvertising();
      } else {
        sendMessage('NAME_UPDATE:$trimmed', echoSelf: false);
      }
    }
  }

  /// Performs a Briar-style Deep Radio Recovery.
  ///
  /// When Android's WifiP2pManager enters a zombie/BUSY state (reason 2 or 8003),
  /// merely restarting discovery fails because the underlying OS Wi-Fi Direct group lock
  /// is still held. This method aggressively tears down all endpoints, discovery,
  /// and advertising, waits 400ms for Android OS to release the radio lock,
  /// clears internal state, and restarts cleanly.
  Future<void> forceDeepReset() async {
    debugPrint('MeshService: forceDeepReset executing deep hardware teardown...');
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryQueue.clear();

    if (activeTransport == MeshTransportType.wifiDirect) {
      await _wifiDirectTransport?.stop();
    } else {
      try { await Nearby().stopAllEndpoints(); } catch (_) {}
      try { await Nearby().stopDiscovery(); } catch (_) {}
      try { await Nearby().stopAdvertising(); } catch (_) {}
    }

    _lanPeerSub?.cancel();
    _lanMsgSub?.cancel();
    _lanReqSub?.cancel();
    _lanProgSub?.cancel();
    await _lanTransport?.stop();
    _lanTransport = null;

    for (final t in _disconnectTimers.values) {
      t.cancel();
    }
    _disconnectTimers.clear();
    _peers.clear();
    _incomingFiles.clear();
    _outgoingFiles.clear();
    _voicePayloadIds.clear();
    _peersController.add([]);

    // Briar pause: wait 400ms for Android OS WifiP2pManager to release the group lock
    await Future.delayed(const Duration(milliseconds: 400));

    _running = false;
    await start();
  }

  Future<void> stop() async {
    _running = false;
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryQueue.clear();
    _wdPeerSub?.cancel();
    _wdMsgSub?.cancel();
    _lanPeerSub?.cancel();
    _lanMsgSub?.cancel();
    _lanReqSub?.cancel();
    _lanProgSub?.cancel();
    await _lanTransport?.stop();
    _lanTransport = null;

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
    _outgoingFiles.clear();
    _voicePayloadIds.clear();
    _peersController.add(peerList);
  }

  void dispose() {
    // 🔴 FIX 1.3: MeshService is a global singleton (see bottom of file).
    // Closing broadcast StreamControllers here means ANY subsequent call
    // to _peersController.add() throws a StateError, bricking discovery
    // until the app is force-stopped and the singleton is recreated.
    // These controllers MUST live for the app's entire lifetime.
    //
    // _peersController.close();
    // _messagesController.close();
    // _connectionRequestsController.close();
  }

  /// Upserts a peer into the map, deduplicating by display name across transports.
  /// Tier 1 (LAN sockets) always takes precedence over Tier 2 (Nearby Connections).
  /// Returns true if the map was modified.
  bool _upsertPeer(MeshPeer newPeer) {
    if (newPeer.name == userName) return false;

    String? staleId;
    bool staleIsConnected = false;
    bool staleIsLan = false;

    for (final entry in _peers.entries) {
      if (entry.key != newPeer.endpointId && entry.value.name.toLowerCase() == newPeer.name.toLowerCase()) {
        staleId = entry.key;
        staleIsConnected = (entry.value.status == PeerStatus.connected || entry.value.status == PeerStatus.reconnecting);
        staleIsLan = entry.key.startsWith('lan_');
        break;
      }
    }
    
    // Never overwrite an active/connecting session with a disconnected beacon
    final existingSameId = _peers[newPeer.endpointId];
    final bool currentIsConnected = existingSameId != null &&
        (existingSameId.status == PeerStatus.connected ||
         existingSameId.status == PeerStatus.reconnecting);

    if ((staleIsConnected || currentIsConnected) && newPeer.status != PeerStatus.connected) {
      return false;
    }

    // Never downgrade an existing LAN socket peer to a Nearby Connections beacon.
    // LAN (Wi-Fi router / Hotspot) is Tier 1 — faster, rock-solid, and immune to Wi-Fi Direct locks.
    if (staleIsLan && !newPeer.endpointId.startsWith('lan_')) {
      return false;
    }

    bool changed = false;
    if (staleId != null) {
      _disconnectTimers.remove(staleId)?.cancel();
      _peers.remove(staleId);
      changed = true;
    }

    final existing = _peers[newPeer.endpointId];
    if (existing == null || existing.status != newPeer.status || existing.name != newPeer.name) {
      _peers[newPeer.endpointId] = newPeer;
      changed = true;
    }
    return changed;
  }

  void _onEndpointFound(String id, String name, String serviceId) {
    if (!name.startsWith(kMeshPeerPrefix)) return;
    if (name == userName) return;
    
    final newPeer = MeshPeer(
      endpointId: id,
      name: name,
      status: PeerStatus.disconnected,
    );

    if (_upsertPeer(newPeer)) {
      _peersController.add(peerList);
      
      // Cancel TTL timer if it came back into range
      _disconnectTimers.remove(id)?.cancel();
    }
  }

  /// Initiate a connection to a discovered peer.
  /// Called when the user taps on a peer in the radar list.
  Future<bool> connectToEndpoint(String endpointId) async {
    if (endpointId.startsWith('lan_')) {
      final ok = await _lanTransport?.connectToPeer(endpointId) ?? false;
      if (ok) {
        final existing = _peers[endpointId];
        if (existing != null) {
          _peers[endpointId] = existing.copyWith(status: PeerStatus.connected);
          _peersController.add(peerList);
        }
      }
      return ok;
    }

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
    // 🔴 FIX 1.1: Nearby fires onEndpointLost when advertising rotates
    // (battery saving), NOT when the TCP/Wi-Fi Direct link drops. The
    // actual disconnection lifecycle is governed by onDisconnected().
    // Overwriting connected → reconnecting here was the #1 cause of
    // "connection drops after 1 text message".
    if (peer.status == PeerStatus.connected || peer.status == PeerStatus.reconnecting) return;

    // Start a TTL timer for cleanup if the endpoint doesn't return.
    _disconnectTimers[id]?.cancel();
    _disconnectTimers[id] = Timer(_disconnectTtl, () {
      final p = _peers.remove(id);
      _disconnectTimers.remove(id);
      if (p != null) _peersController.add(peerList);
    });
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) {
    // 🔴 FIX 1.2: Add the peer immediately so hasLiveLink is true during
    // the handshake. Previously the peer wasn't in _peers yet, so the
    // 15s discovery timer would fire restartDiscovery/restartAdvertising
    // and tear down the radio mid-negotiation.
    _pendingConnectionNames[id] = info.endpointName;
    _peers[id] = MeshPeer(
      endpointId: id,
      name: info.endpointName,
      status: PeerStatus.reconnecting, // "negotiating" — protects hasLiveLink
    );
    _peersController.add(peerList);

    if (info.isIncomingConnection) {
      _connectionRequestsController.add(ConnectionRequestEvent(id, info.endpointName));
    } else {
      acceptConnection(id);
    }
  }

  void acceptConnection(String id) {
    if (id.startsWith('lan_')) {
      _lanTransport?.acceptConnection(id);
      final existing = _peers[id];
      if (existing != null) {
        _peers[id] = existing.copyWith(status: PeerStatus.connected);
        _peersController.add(peerList);
      }
      return;
    }
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  void rejectConnection(String id) {
    if (id.startsWith('lan_')) {
      _lanTransport?.rejectConnection(id);
      final existing = _peers[id];
      if (existing != null) {
        _peers[id] = existing.copyWith(status: PeerStatus.disconnected);
        _peersController.add(peerList);
      }
      return;
    }
    Nearby().rejectConnection(id);
  }

  void _onConnectionResult(String id, Status status) {
    if (status == Status.CONNECTED) {
      _disconnectTimers.remove(id)?.cancel();
      final existing = _peers[id];
      // 🔴 FIX 3.1: Use the name from discovery or connection initiation,
      // not the raw endpoint ID. Previously when existing was null (direct
      // incoming connection without prior discovery), the peer's name was
      // set to the endpoint ID, displaying gibberish instead of the user name.
      _peers[id] = MeshPeer(
        endpointId: id,
        name: existing?.name ?? _pendingConnectionNames.remove(id) ?? id,
        status: PeerStatus.connected,
      );
      _peersController.add(peerList);
      _flushRetryQueue(targetEndpointId: id);
    } else {
      _peers.remove(id);
      _pendingConnectionNames.remove(id);
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

  /// File extensions a peer is allowed to induce, per message type.
  ///
  /// The extension is the ONLY thing taken from a peer-supplied filename
  /// hint — see [safeExtensionFor] for why the name itself is discarded.
  static const _allowedExtensions = <MessageType, Set<String>>{
    MessageType.voice: {'m4a', 'aac', 'wav', 'mp3', 'ogg', 'opus', '3gp'},
    MessageType.image: {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'},
    MessageType.video: {'mp4', 'mov', '3gp', 'mkv', 'webm'},
  };

  static const _defaultExtensions = <MessageType, String>{
    MessageType.voice: 'm4a',
    MessageType.image: 'jpg',
    MessageType.video: 'mp4',
  };

  /// Pull a safe file extension out of a peer-supplied filename hint.
  ///
  /// **Why the peer's filename is never used as a filename.** The hint
  /// arrives inside a bytes payload from another device
  /// (`voice:<id>:<basename>`), so every byte of it is attacker-controlled.
  /// It used to be concatenated straight onto the app documents directory:
  ///
  /// ```dart
  /// final dest = '${dir.path}/$basename';   // basename came from the peer
  /// ```
  ///
  /// That is the same directory [ModelManager] keeps its weights in, as
  /// `model_<variant>.litertlm` — a name any reader of this repo knows. So a
  /// connected peer could send a one-byte file hinted
  /// `voice:1:model_e2b.litertlm` and destroy the 2.5 GB on-device model,
  /// silently killing offline AI, which is the whole premise of this app. A
  /// `../` in the hint escaped upward into `shared_prefs/` and `databases/`
  /// as well.
  ///
  /// The hint's only legitimate purpose was ever to carry the extension, so
  /// that is all we read from it — the receiver names the file itself. An
  /// unrecognised or absent extension falls back to the default for [type]
  /// rather than being honoured, so no peer input reaches the path at all.
  @visibleForTesting
  static String safeExtensionFor(String hint, MessageType type) {
    if (type == MessageType.file) {
      final lastSegment = hint.split(RegExp(r'[/\\]')).last;
      final dot = lastSegment.lastIndexOf('.');
      if (dot >= 0 && dot < lastSegment.length - 1) {
        final ext = lastSegment.substring(dot + 1).toLowerCase();
        if (RegExp(r'^[a-z0-9]{1,10}$').hasMatch(ext)) {
          return ext;
        }
      }
      return 'bin';
    }
    final fallback = _defaultExtensions[type] ?? 'bin';
    final allowed = _allowedExtensions[type];
    if (allowed == null) return fallback;

    // Take the text after the final dot of the final path segment, so
    // `../../x.tar.gz` yields `gz` and `..` yields nothing.
    final lastSegment = hint.split(RegExp(r'[/\\]')).last;
    final dot = lastSegment.lastIndexOf('.');
    if (dot < 0 || dot == lastSegment.length - 1) return fallback;

    final ext = lastSegment.substring(dot + 1).toLowerCase();
    return allowed.contains(ext) ? ext : fallback;
  }

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
          if (id != null) {
            _incomingFilenames[id] = parts[2];
            _voicePayloadIds.add(id);
          }
        }
        return;
      }
      // General file filename hint: "file:<payloadId>:<basename>"
      if (text.startsWith('file:')) {
        final parts = text.split(':');
        if (parts.length >= 3) {
          final id = int.tryParse(parts[1]);
          if (id != null) {
            final basename = parts.sublist(2).join(':');
            _incomingFilenames[id] = '$basename|file';
          }
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
      if (text.startsWith('NAME_UPDATE:')) {
        final newDisplayName = text.substring('NAME_UPDATE:'.length);
        final peer = _peers[endpointId];
        if (peer != null) {
          _peers[endpointId] = peer.copyWith(name: '$kMeshPeerPrefix$newDisplayName');
          _peersController.add(peerList);
        }
        return;
      }
      if (text == 'PING') {
        sendMessage('PONG', targetEndpointId: endpointId, echoSelf: false);
        return;
      }
      if (text == 'PONG') {
        return;
      }
      // Safety-status intercept: feed into SafetyStatusService so the
      // admin dashboard sees live safe/danger counts. Does NOT
      // suppress the chat bubble — the user still sees the report as
      // a text message in mesh chat.
      if (text.startsWith('SAFE:') || text.startsWith('DANGER:')) {
        final jsonPart = text.substring(text.indexOf(':') + 1);
        safetyStatusService.ingestJson(jsonPart);
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

  /// SharedPreferences key for "copy media a peer sends me into my gallery".
  /// Default OFF — see the call site in [_materializeFile].
  static const prefAutoSaveMeshMedia = 'pref_mesh_autosave_media';

  Future<bool> _autoSaveMediaEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefAutoSaveMeshMedia) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Materialize a received FILE payload from a `content://` URI into real
  /// storage — always the app-private documents dir, under a name this
  /// device chooses. Images/videos are additionally copied to the gallery
  /// only when the user has opted in.
  Future<_MaterializedFile?> _materializeFile(
      int payloadId, String sourceUri) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customDir = prefs.getString('pref_mesh_storage_dir');
      Directory dir;
      if (customDir != null && Directory(customDir).existsSync()) {
        dir = Directory(customDir);
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      final hint = _incomingFilenames.remove(payloadId) ?? '';

      // hint format: "basename" (voice) or "basename|type" (media / file)
      String rawName;
      MessageType msgType;
      if (hint.contains('|')) {
        final parts = hint.split('|');
        rawName = parts[0];
        msgType = parts[1] == 'video'
            ? MessageType.video
            : parts[1] == 'file'
                ? MessageType.file
                : MessageType.image;
      } else {
        rawName = hint;
        msgType = MessageType.voice;
      }

      // The receiver names the file; only the extension is taken from the
      // peer, and only from an allowlist. See [safeExtensionFor] — the peer's
      // own basename used to land in this path verbatim, which let a
      // connected device overwrite the on-device model weights.
      final ext = safeExtensionFor(rawName, msgType);
      final dest = msgType == MessageType.file
          ? '${dir.path}/mesh_file_${payloadId}_${_sanitizeFilename(rawName)}'
          : '${dir.path}/mesh_${msgType.name}_$payloadId.$ext';
      await Nearby().copyFileAndDeleteOriginal(sourceUri, dest);

      // Copy images/videos into the device gallery — but only with standing
      // consent. This writes a file a stranger in mesh range chose, under a
      // name they influenced, into the user's camera roll; doing that
      // unconditionally made every accepted peer able to drop media onto the
      // device. Opt-in, default off (see SettingsScreen → mesh media).
      if (msgType == MessageType.image || msgType == MessageType.video) {
        if (await _autoSaveMediaEnabled()) {
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
      }

      return _MaterializedFile(dest, msgType);
    } catch (e) {
      debugPrint('MeshService: failed to materialize file: $e');
      _incomingFilenames.remove(payloadId);
      return null;
    }
  }

  static String _sanitizeFilename(String name) {
    final clean = name.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    return clean.isNotEmpty ? clean : 'attachment.bin';
  }

  final _transferProgressController =
      StreamController<FileTransferProgress>.broadcast();
  Stream<FileTransferProgress> get transferProgress =>
      _transferProgressController.stream;

  /// Track outgoing file payloads for progress reporting.
  final Map<int, String> _outgoingFiles = {};

  /// 🔴 FIX 5.4: Deferred files — FILE payload completed before the
  /// bytes hint arrived. Holds the source URI until the hint comes in.
  final Map<int, _DeferredFile> _deferredFiles = {};

  // 🔴 FIX 1 + 5.1 + 5.4: Emit progress on every update, not just terminal
  // states. Deferred materialization for the hint race condition.
  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    // 🔴 FIX: Voice clips do not show a file transfer progress bar
    final isVoice = _voicePayloadIds.contains(update.id);
    if (isVoice) {
      if (update.status == PayloadStatus.SUCCESS ||
          update.status == PayloadStatus.FAILURE ||
          update.status == PayloadStatus.CANCELED) {
        _voicePayloadIds.remove(update.id);
      }
    } else {
      // Emit progress for in-flight transfers (both incoming and outgoing).
      final isIncoming = _incomingFiles.containsKey(update.id);
      final isOutgoing = _outgoingFiles.containsKey(update.id);
      if (isIncoming || isOutgoing) {
        _transferProgressController.add(FileTransferProgress(
          payloadId: update.id,
          endpointId: endpointId,
          bytesTransferred: update.bytesTransferred,
          totalBytes: update.totalBytes,
          isSending: isOutgoing,
          isComplete: update.status == PayloadStatus.SUCCESS,
          isFailed: update.status == PayloadStatus.FAILURE ||
              update.status == PayloadStatus.CANCELED,
        ));
      }
    }

    if (update.status == PayloadStatus.SUCCESS) {
      _outgoingFiles.remove(update.id);
      final sourceUri = _incomingFiles.remove(update.id);
      if (sourceUri == null) return;

      // 🔴 FIX 5.4: Check if the bytes hint has already arrived.
      if (_incomingFilenames.containsKey(update.id)) {
        // Hint is here — materialize immediately.
        _materializeAndEmit(update.id, sourceUri, endpointId);
      } else {
        // Hint hasn't arrived yet — defer materialization.
        _deferredFiles[update.id] = _DeferredFile(sourceUri, endpointId);
        Timer(const Duration(seconds: 10), () {
          // Timeout: if hint still hasn't arrived, materialize with defaults.
          final deferred = _deferredFiles.remove(update.id);
          if (deferred != null) {
            _materializeAndEmit(update.id, deferred.uri, deferred.endpointId);
          }
        });
      }
    } else if (update.status == PayloadStatus.FAILURE ||
        update.status == PayloadStatus.CANCELED) {
      _incomingFiles.remove(update.id);
      _incomingFilenames.remove(update.id);
      _outgoingFiles.remove(update.id);
      _voicePayloadIds.remove(update.id);
    }
  }

  /// Materialize a completed file transfer and emit a MeshMessage.
  void _materializeAndEmit(int payloadId, String sourceUri, String endpointId) {
    _materializeFile(payloadId, sourceUri).then((result) {
      if (result == null) return;
      final peerName = _peers[endpointId]?.name ?? endpointId;
      final text = result.type == MessageType.file
          ? result.path.split(RegExp(r'[/\\]')).last.replaceFirst('mesh_file_${payloadId}_', '')
          : '';
      _messagesController.add(MeshMessage(
        senderId: endpointId,
        senderName: peerName,
        text: text,
        type: result.type,
        filePath: result.path,
      ));
    });
  }

  /// Returns true if at least one peer received the message.
  bool sendMessage(
    String text, {
    String? targetEndpointId,
    bool echoSelf = true,
    bool enqueueOnFailure = true,
  }) {
    var delivered = false;
    if (_peers.isNotEmpty) {
      for (final peer in _peers.values) {
        if (peer.status == PeerStatus.connected) {
          if (targetEndpointId == null || peer.endpointId == targetEndpointId) {
            if (peer.endpointId.startsWith('lan_')) {
              final ok = _lanTransport?.sendText(peer.endpointId, text) ?? false;
              if (ok) delivered = true;
            } else if (activeTransport == MeshTransportType.wifiDirect) {
              final ok = _wifiDirectTransport?.sendTextToPeer(
                      peer.endpointId, text) ??
                  false;
              if (ok) delivered = true;
            } else {
              try {
                final bytes = Uint8List.fromList(utf8.encode(text));
                Nearby().sendBytesPayload(peer.endpointId, bytes);
                delivered = true;
              } catch (e) {
                debugPrint('MeshService: sendBytes failed to ${peer.name}: $e');
              }
            }
          }
        }
      }
    }

    // 🔴 FIX 8.5: Enqueue user message if delivery failed (e.g. peer is
    // temporarily disconnected or reconnecting), so it will automatically
    // retry when the peer is back online.
    if (!delivered && enqueueOnFailure && targetEndpointId != null && _isUserMessage(text)) {
      _retryQueue.add(_QueuedMessage(
        text: text,
        targetEndpointId: targetEndpointId,
      ));
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

  static bool _isUserMessage(String text) {
    if (text == 'PING' || text == 'PONG') return false;
    if (text.startsWith('CALL_SIG:') ||
        text.startsWith('NAME_UPDATE:') ||
        text.startsWith('voice:') ||
        text.startsWith(_kMediaHintPrefix) ||
        text.startsWith('GRP_') ||
        text.startsWith('SOS_')) {
      return false;
    }
    return true;
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
      // Route through the active transport.
      if (activeTransport == MeshTransportType.wifiDirect) {
        _wifiDirectTransport?.sendBytes(peer.endpointId, bytes);
      } else {
        try {
          Nearby().sendBytesPayload(peer.endpointId, bytes);
        } catch (e) {
          debugPrint('MeshService: failed to send bytes to ${peer.name}: $e');
        }
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
          if (peer.endpointId.startsWith('lan_')) {
            _lanTransport?.sendFile(peer.endpointId, sendPath, type: MessageType.voice);
          } else if (activeTransport == MeshTransportType.wifiDirect) {
            _wifiDirectTransport?.sendFile(sendPath,
                targetPeerId: peer.endpointId);
          } else {
            try {
              final filePayloadId =
                  Nearby().sendFilePayload(peer.endpointId, sendPath);
              filePayloadId.then((payloadId) {
                _voicePayloadIds.add(payloadId);
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
          if (peer.endpointId.startsWith('lan_')) {
            _lanTransport?.sendFile(peer.endpointId, sendPath, type: type);
          } else if (activeTransport == MeshTransportType.wifiDirect) {
            _wifiDirectTransport?.sendFile(sendPath,
                targetPeerId: peer.endpointId);
          } else {
            try {
              final filePayloadId =
                  Nearby().sendFilePayload(peer.endpointId, sendPath);
              filePayloadId.then((payloadId) {
                _outgoingFiles[payloadId] = sendPath;
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

  /// Send a general file (documents, archives, etc.) to a peer over the mesh.
  Future<String?> sendFileMessage(
    String filePath, {
    String? targetEndpointId,
  }) async {
    if (_peers.isEmpty) return null;
    final basename = filePath.split(RegExp(r'[/\\]')).last;

    // Persist into app-private storage so sender retains a copy
    String? localPath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = '${dir.path}/mesh_file_${DateTime.now().millisecondsSinceEpoch}_${_sanitizeFilename(basename)}';
      final src = File(filePath);
      if (await src.exists()) {
        await src.copy(dest);
        localPath = dest;
      }
    } catch (e) {
      debugPrint('MeshService: failed to persist sender file: $e');
      localPath = filePath;
    }

    final sendPath = localPath ?? filePath;
    for (final peer in _peers.values) {
      if (peer.status == PeerStatus.connected) {
        if (targetEndpointId == null || peer.endpointId == targetEndpointId) {
          if (peer.endpointId.startsWith('lan_')) {
            _lanTransport?.sendFile(peer.endpointId, sendPath, type: MessageType.file);
          } else if (activeTransport == MeshTransportType.wifiDirect) {
            _wifiDirectTransport?.sendFile(sendPath,
                targetPeerId: peer.endpointId);
          } else {
            try {
              final filePayloadId =
                  Nearby().sendFilePayload(peer.endpointId, sendPath);
              filePayloadId.then((payloadId) {
                _outgoingFiles[payloadId] = sendPath;
                // hint: "file:<id>:<basename>"
                final hint = utf8.encode('file:$payloadId:$basename');
                Nearby().sendBytesPayload(
                  peer.endpointId,
                  Uint8List.fromList(hint),
                );
              }).catchError((_) {});
            } catch (e) {
              debugPrint('MeshService: sendFileMessage failed: $e');
            }
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
      text: basename,
      type: MessageType.file,
      filePath: sendPath,
    ));
    return sendPath;
  }
}

class _DeferredFile {
  final String uri;
  final String endpointId;
  _DeferredFile(this.uri, this.endpointId);
}

class FileTransferProgress {
  final int payloadId;
  final String? endpointId;
  final int bytesTransferred;
  final int totalBytes;
  final bool isSending;
  final bool isComplete;
  final bool isFailed;

  FileTransferProgress({
    required this.payloadId,
    this.endpointId,
    required this.bytesTransferred,
    required this.totalBytes,
    required this.isSending,
    required this.isComplete,
    required this.isFailed,
  });

  double get percent => totalBytes > 0 ? (bytesTransferred / totalBytes * 100) : 0.0;
}

/// Result of materializing a received FILE payload.
class _MaterializedFile {
  final String path;
  final MessageType type;
  const _MaterializedFile(this.path, this.type);
}

/// Pending outgoing message for offline/reconnecting peer with retry count.
class _QueuedMessage {
  final String text;
  final String targetEndpointId;
  int retries = 0;
  final DateTime createdAt;
  _QueuedMessage({
    required this.text,
    required this.targetEndpointId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

final meshService = MeshService._(
  userName: '$kMeshPeerPrefix${Random.secure().nextInt(0x1000000).toRadixString(16).padLeft(6, '0')}',
);