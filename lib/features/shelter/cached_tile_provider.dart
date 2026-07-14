import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Utility for checking network connectivity and managing offline state.
class ConnectivityHelper {
  /// Returns true if the device has any network connection (WiFi, cellular,
  /// or ethernet). Returns false if only none/bluetooth.
  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none) && result.isNotEmpty;
  }

  /// Streams connectivity changes. Emits true when online, false when offline.
  static Stream<bool> get onConnectivityChanged {
    return Connectivity().onConnectivityChanged.map((results) {
      return !results.contains(ConnectivityResult.none) && results.isNotEmpty;
    });
  }
}

/// Checks if cached map tiles exist in the app cache directory.
///
/// Used by the shelter map to determine whether to attempt tile rendering
/// when offline. If tiles were previously viewed while online, they will
/// be served from the HTTP cache.
class TileCacheInfo {
  static Future<bool> hasCachedTiles() async {
    try {
      final cache = await getTemporaryDirectory();
      final tileDir = Directory('${cache.path}/map_tiles');
      if (!tileDir.existsSync()) return false;
      return tileDir.listSync(recursive: true).any((e) => e is File);
    } catch (_) {
      return false;
    }
  }
}
