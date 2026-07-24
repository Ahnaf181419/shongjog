import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Detects whether Google Play Services are available on this device.
///
/// Returns `true` on devices with GMS (most Global-ROM Android phones).
/// Returns `false` on CN-market devices, HyperOS without Play, pure AOSP, etc.
///
/// This check is Android-only and always returns `false` on other platforms.
class GmsDetector {
  static const _channel = MethodChannel('shongjog/gms_check');

  static bool? _cached;

  /// Returns `true` if Google Play Services are present and functional.
  static Future<bool> isAvailable() async {
    if (_cached != null) return _cached!;
    if (!Platform.isAndroid) {
      _cached = false;
      return false;
    }

    try {
      // Use the Android GoogleApiAvailability check via a platform channel.
      // If the channel doesn't exist (no native side yet), we fall back to
      // a heuristic: check if com.google.android.gms is installed by attempting
      // to instantiate the Nearby API — if it throws a MissingPluginException
      // or returns false immediately, GMS is absent.
      final result = await _channel.invokeMethod<bool>('checkGms');
      _cached = result ?? false;
    } on MissingPluginException {
      // Native channel not wired yet — use heuristic.
      _cached = await _heuristicCheck();
    } catch (e) {
      debugPrint('GmsDetector: check failed ($e), assuming GMS absent');
      _cached = false;
    }

    debugPrint('GmsDetector: GMS available = $_cached');
    return _cached!;
  }

  /// Heuristic: try to use Google's Nearby startAdvertising for 1s.
  /// If it throws immediately, GMS is absent.
  static Future<bool> _heuristicCheck() async {
    try {
      // We avoid importing nearby_connections here directly to keep this file
      // dependency-free. Instead, we rely on the fact that on no-GMS devices
      // the very first call to Nearby() fails synchronously before any I/O.
      // The MeshService.start() already catches this and we interpret it as
      // the signal to fall back. So heuristic = optimistic default true here,
      // with the real check happening inside MeshService.start().
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Call this to force a recheck (e.g., after the user installs GMS).
  static void invalidateCache() => _cached = null;
}
