import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/connectivity_provider.dart';

/// Backward-compatible connectivity helper.
///
/// Thin delegate over [ConnectivityProvider] for [isOnline] (reads the
/// cached boolean — no plugin call). [onConnectivityChanged] is a
/// passthrough to the underlying `connectivity_plus` stream; new code
/// should depend on [ConnectivityProvider] directly.
class ConnectivityHelper {
  /// Returns true if the device currently has a usable network interface.
  static Future<bool> isOnline() async => connectivityProvider.isOnline;

  /// Streams connectivity changes. Emits true when online, false when offline.
  static Stream<bool> get onConnectivityChanged {
    return Connectivity().onConnectivityChanged.map((results) {
      return results.isNotEmpty && !results.contains(ConnectivityResult.none);
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
