import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
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

/// Internal [ImageProvider] that serves a tile from disk cache, or
/// fetches from network and caches it.
class _CachedTileImageProvider extends ImageProvider<_CachedTileImageProvider> {
  final String _url;
  final Directory _cacheDir;
  final int _z;
  final int _x;
  final int _y;

  _CachedTileImageProvider({
    required this._url,
    required this._cacheDir,
    required this._z,
    required this._x,
    required this._y,
  });

  @override
  Future<_CachedTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  File get _cacheFile =>
      File('${_cacheDir.path}/$_z/$_x/$_y.png');

  Future<Uint8List?> _readCache() async {
    try {
      final file = _cacheFile;
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _writeCache(Uint8List bytes) async {
    try {
      final dir = _cacheFile.parent;
      if (!dir.existsSync()) dir.createSync(recursive: true);
      await _cacheFile.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Non-critical — cache write failure is silent
    }
  }

  @override
  ImageStreamCompleter loadImage(
    _CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () => [
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<String>('Image URL', _url),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    _CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    // 1. Try disk cache
    final cached = await _readCache();
    if (cached != null) {
      final buffer = await ui.ImmutableBuffer.fromUint8List(cached);
      return await decode(buffer);
    }

    // 2. Fetch from network
    final response = await http.get(
      Uri.parse(_url),
      headers: {'User-Agent': 'com.shongjog.app/1.0'},
    );

    if (response.statusCode != 200) {
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: Uri.parse(_url),
      );
    }

    final bytes = response.bodyBytes;

    // 3. Write to cache (fire and forget — don't block image display)
    _writeCache(bytes);

    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return await decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CachedTileImageProvider && _url == other._url);

  @override
  int get hashCode => _url.hashCode;
}

/// A [TileProvider] that caches OSM tiles to disk for offline use.
///
/// When online, tiles are fetched via HTTP and simultaneously saved to
/// `<tempDir>/map_tiles/{z}/{x}/{y}.png`. When offline, cached tiles
/// are served from disk automatically.
class CachedTileProvider extends TileProvider {
  Directory? _cacheDir;
  bool _initialized = false;

  Future<void> _ensureCacheDir() async {
    if (_initialized) return;
    try {
      final temp = await getTemporaryDirectory();
      _cacheDir = Directory('${temp.path}/map_tiles');
      if (!_cacheDir!.existsSync()) {
        _cacheDir!.createSync(recursive: true);
      }
    } catch (_) {
      debugPrint('CachedTileProvider: could not create cache dir');
    }
    _initialized = true;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return _CachedTileImageProvider(
      url: url,
      cacheDir: _cacheDir ?? Directory(''),
      z: coordinates.z,
      x: coordinates.x,
      y: coordinates.y,
    );
  }

  /// Manually cache a tile image bytes for given coordinates.
  Future<void> cacheTile(int z, int x, int y, List<int> bytes) async {
    await _ensureCacheDir();
    if (_cacheDir == null) return;
    try {
      final tileDir = Directory('${_cacheDir!.path}/$z/$x');
      if (!tileDir.existsSync()) tileDir.createSync(recursive: true);
      final file = File('${_cacheDir!.path}/$z/$x/$y.png');
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  /// Read cached tile bytes, or null if not cached.
  Future<Uint8List?> readCachedTile(int z, int x, int y) async {
    await _ensureCacheDir();
    if (_cacheDir == null) return null;
    try {
      final file = File('${_cacheDir!.path}/$z/$x/$y.png');
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (_) {}
    return null;
  }

  /// Clears all cached tiles.
  Future<void> clearCache() async {
    await _ensureCacheDir();
    try {
      if (_cacheDir != null && _cacheDir!.existsSync()) {
        await _cacheDir!.delete(recursive: true);
        _cacheDir = null;
        _initialized = false;
      }
    } catch (_) {
      debugPrint('CachedTileProvider: failed to clear cache');
    }
  }

  /// Check if any tiles are cached.
  Future<bool> hasCachedTiles() async {
    await _ensureCacheDir();
    if (_cacheDir == null || !_cacheDir!.existsSync()) return false;
    return _cacheDir!.listSync(recursive: true).any((e) => e is File);
  }
}

/// Global tile cache instance shared across all map screens.
final CachedTileProvider tileCacheProvider = CachedTileProvider();
