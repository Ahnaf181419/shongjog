import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

enum DeviceTier { low, mid, high }
enum ModelVariant { e2b, e4b, twelveb }

class ModelRecommendation {
  final ModelVariant variant;
  final String label;
  final String sizeBn;
  final int sizeBytes;
  final bool recommended;
  final bool advancedOnly;
  final String downloadUrl;
  final String description;

  const ModelRecommendation({
    required this.variant,
    required this.label,
    required this.sizeBn,
    required this.sizeBytes,
    required this.recommended,
    required this.advancedOnly,
    required this.downloadUrl,
    required this.description,
  });
}

class DeviceCapability {
  // Model file sizes in bytes
  static const int _e2bBytes = 2003697664; // ~1.87 GB
  static const int _e4bBytes = 4000000000; // ~3.7 GB (approx)
  static const int _12bBytes = 10000000000; // ~9.3 GB (approx)

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
    } catch (_) {}
    return 0;
  }

  static Future<List<ModelRecommendation>> getRecommendations() async {
    final tier = await detectTier();

    return [
      ModelRecommendation(
        variant: ModelVariant.e2b,
        label: 'Gemma 4 E2B',
        sizeBn: '~১-২ GB',
        sizeBytes: _e2bBytes,
        recommended: true,
        advancedOnly: false,
        description: 'হালকা ও দ্রুত। সব ডিভাইসে কাজ করবে।',
        downloadUrl:
            'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-web.task',
      ),
      ModelRecommendation(
        variant: ModelVariant.e4b,
        label: 'Gemma 4 E4B',
        sizeBn: '~২-৪ GB',
        sizeBytes: _e4bBytes,
        recommended: tier == DeviceTier.mid || tier == DeviceTier.high,
        advancedOnly: false,
        description: 'ভালো মানের উত্তর। ৬GB+ র‍্যাম প্রয়োজন।',
        downloadUrl:
            'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it-web.task',
      ),
      ModelRecommendation(
        variant: ModelVariant.twelveb,
        label: 'Gemma 4 12B',
        sizeBn: '~৭-১০ GB',
        sizeBytes: _12bBytes,
        recommended: tier == DeviceTier.high,
        advancedOnly: true,
        description: 'সেরা মানের উত্তর। ১২GB+ র‍্যাম প্রয়োজন।',
        downloadUrl:
            'https://huggingface.co/litert-community/gemma-4-12B-it-litert-lm/resolve/main/gemma-4-12B-it-web.task',
      ),
    ];
  }

  /// Get the recommended model variant for this device.
  static Future<ModelVariant> getRecommendedVariant() async {
    final tier = await detectTier();
    switch (tier) {
      case DeviceTier.low:
        return ModelVariant.e2b;
      case DeviceTier.mid:
        return ModelVariant.e4b;
      case DeviceTier.high:
        return ModelVariant.e4b; // E4B is the sweet spot; 12B is opt-in
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
