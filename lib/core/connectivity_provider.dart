import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide reactive view of device connectivity.
///
/// Wraps [Connectivity] from `connectivity_plus` so the rest of the app can
/// read a cached `isOnline` boolean and rebuild via [ChangeNotifier] when the
/// state flips, instead of polling `checkConnectivity()` on every network
/// call. The plugin emits a fresh value whenever the OS reports a change
/// (WiFi association, airplane mode, etc.) — typical latency is 1–2s on
/// Android, which is acceptable for the UI surfaces that consume this.
///
/// Initial state is `false` (offline-first) and is corrected on the first
/// [initialize] read. Call [initialize] exactly once during app startup
/// (see `lib/main.dart`). Defaulting to offline aligns with the product
/// thesis — UI surfaces never falsely claim "online" before the plugin
/// reports a usable network.
class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = false;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> initialize() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = _hasUsable(results);
    notifyListeners();

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final next = _hasUsable(results);
      if (next != _isOnline) {
        _isOnline = next;
        notifyListeners();
      }
    });
  }

  static bool _hasUsable(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    if (results.contains(ConnectivityResult.none)) return false;
    return true;
  }

  /// Test-only override. Lets widget tests force an online/offline state
  /// without invoking the platform plugin channel.
  @visibleForTesting
  void debugSetOnline(bool value) {
    if (_isOnline != value) {
      _isOnline = value;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// App-wide singleton. Initialize exactly once in `main.dart`.
final ConnectivityProvider connectivityProvider = ConnectivityProvider();
