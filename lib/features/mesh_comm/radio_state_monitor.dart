import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class RadioStateMonitor {
  final _connectivity = Connectivity();
  StreamSubscription? _sub;
  
  final _wifiStateController = StreamController<bool>.broadcast();
  Stream<bool> get wifiEnabledStream => _wifiStateController.stream;

  bool _isWifiEnabled = false;
  bool get isWifiEnabled => _isWifiEnabled;

  void start() {
    _checkInitial();
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final hasWifi = results.contains(ConnectivityResult.wifi);
      if (hasWifi != _isWifiEnabled) {
        _isWifiEnabled = hasWifi;
        _wifiStateController.add(hasWifi);
      }
    });
  }

  Future<void> _checkInitial() async {
    final results = await _connectivity.checkConnectivity();
    final hasWifi = results.contains(ConnectivityResult.wifi);
    _isWifiEnabled = hasWifi;
    _wifiStateController.add(hasWifi);
  }

  void stop() {
    _sub?.cancel();
    _wifiStateController.close();
  }
}
