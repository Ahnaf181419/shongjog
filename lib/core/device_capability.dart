import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

enum DeviceTier { low, mid, high }
enum ModelVariant { e2b, e4b, twelveb }

class ModelRecommendation {
  final ModelVariant variant;
  final String label;
  final String sizeBn;
  final int sizeBytes;
  final bool recommended;
  final bool advancedOnly;

  /// False when the download URL or byte size has not been verified against
  /// the live host. Unavailable variants must not be offered for download.
  final bool available;
  final String downloadUrl;
  final String description;

  const ModelRecommendation({
    required this.variant,
    required this.label,
    required this.sizeBn,
    required this.sizeBytes,
    required this.recommended,
    required this.advancedOnly,
    this.available = true,
    required this.downloadUrl,
    required this.description,
  });
}

class DeviceCapability {
  // Sizes are the exact Content-Length of each `.litertlm` reported by
  // huggingface.co (verified 2026-07-16). isOnDisk() compares against these
  // with a 99% floor, so a guessed value silently rejects a complete download
  // — always re-check with `curl -sIL <url> | grep -i content-length`.
  //
  // These are the `.litertlm` builds, NOT the repo's `-web.task`. The `.task`
  // file there is a raw-TFL3 WebAssembly build (magic `TFL3`, not the `PK`
  // zip a MediaPipe bundle must be) documented only under the model card's
  // "Running on Web with MediaPipe" section. Android has no `.task` for
  // Gemma 4 at all; `.litertlm` + the LiteRT-LM engine is its only path.
  static const int _e2bBytes = 2588147712; // ~2.47 GB (verified)
  static const int _e4bBytes = 3659530240; // ~3.49 GB (verified)
  static const int _twelveBBytes = 10000000000; // unverified — URL is 404

  static int? _cachedRamMb;

  /// Detect device tier using device_info_plus for accurate RAM detection.
  ///
  /// On Android, uses [AndroidDeviceInfo.totalMemory] which reads the
  /// hardware-reported total physical memory — much more reliable than
  /// parsing `/proc/meminfo` via Process.run.
  static Future<DeviceTier> detectTier() async {
    try {
      if (!Platform.isAndroid) return DeviceTier.mid;

      final ramMb = await _getTotalRamMb();
      if (ramMb == 0) return DeviceTier.mid;

      if (ramMb <= 4096) {
        return DeviceTier.low;
      } else if (ramMb <= 8192) {
        return DeviceTier.mid;
      } else {
        return DeviceTier.high;
      }
    } catch (e) {
      return DeviceTier.mid;
    }
  }

  /// Get total RAM in MB using device_info_plus.
  static Future<int> _getTotalRamMb() async {
    if (_cachedRamMb != null) return _cachedRamMb!;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      // physicalRamSize is in megabytes on Android
      _cachedRamMb = androidInfo.physicalRamSize;
      return _cachedRamMb!;
    } catch (e) {
      // Fallback to /proc/meminfo if device_info_plus fails
      return _getRamFromProcMeminfo();
    }
  }

  /// Fallback: parse /proc/meminfo if device_info_plus is unavailable.
  static Future<int> _getRamFromProcMeminfo() async {
    try {
      final result = await Process.run('cat', ['/proc/meminfo']);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.startsWith('MemTotal:')) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final kb = int.tryParse(parts[1]) ?? 0;
              return kb ~/ 1024;
            }
          }
        }
      }
    } catch (e) { debugPrint("[Catch] device_capability: $e"); }
    return 0;
  }

  static Future<List<ModelRecommendation>> getRecommendations() async {
    final tier = await detectTier();

    return [
      ModelRecommendation(
        variant: ModelVariant.e2b,
        label: 'Gemma 4 E2B',
        sizeBn: '~২.৫ GB',
        sizeBytes: _e2bBytes,
        recommended: true,
        advancedOnly: false,
        description: 'হালকা ও দ্রুত। সব ডিভাইসে কাজ করবে।',
        downloadUrl:
            'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
      ),
      ModelRecommendation(
        variant: ModelVariant.e4b,
        label: 'Gemma 4 E4B',
        sizeBn: '~৩.৫ GB',
        sizeBytes: _e4bBytes,
        recommended: tier == DeviceTier.mid || tier == DeviceTier.high,
        advancedOnly: false,
        description: 'ভালো মানের উত্তর। ৬GB+ র‍্যাম প্রয়োজন।',
        downloadUrl:
            'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
      ),
      ModelRecommendation(
        variant: ModelVariant.twelveb,
        label: 'Gemma 4 12B',
        sizeBn: '~৭-১০ GB',
        sizeBytes: _twelveBBytes,
        recommended: false,
        advancedOnly: true,
        // URL returned 404 on 2026-07-15 and the size is a placeholder.
        // Kept in the catalog so on-disk lookups stay total, but hidden
        // from the picker until spike-tested (docs/spike-results.md).
        available: false,
        description: 'সেরা মানের উত্তর। ১২GB+ র‍্যাম প্রয়োজন।',
        downloadUrl:
            'https://huggingface.co/litert-community/gemma-4-12B-it-litert-lm/resolve/main/gemma-4-12B-it-web.task',
      ),
    ];
  }

  /// Get the recommended model variant for this device.
  ///
  /// E2B is the default everywhere except high-RAM phones. It is the product's
  /// documented target (AGENTS.md) and the model card measures it at ~1.7 GB
  /// CPU / 0.7 GB GPU at runtime on top of a 2.5 GB download — comfortable on
  /// the ৳15,000-class phones this app is for. E4B roughly doubles both, so on
  /// a 6 GB device (which lands in `mid`) it risks the OOM that shows up as a
  /// silent fall back to corpus answers. It stays one tap away in Settings for
  /// anyone who wants it.
  static Future<ModelVariant> getRecommendedVariant() async {
    final tier = await detectTier();
    switch (tier) {
      case DeviceTier.low:
        return ModelVariant.e2b;
      case DeviceTier.mid:
        return ModelVariant.e2b;
      case DeviceTier.high:
        return ModelVariant.e4b; // 12B stays opt-in / unverified
    }
  }

  /// Format bytes to human-readable Bangla string.
  static String formatBytesBn(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
