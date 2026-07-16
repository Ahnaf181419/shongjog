import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/device_capability.dart';

void main() {
  group('DeviceCapability.getRecommendations', () {
    test('covers every ModelVariant so on-disk lookups stay total', () async {
      final recs = await DeviceCapability.getRecommendations();
      for (final v in ModelVariant.values) {
        expect(recs.where((r) => r.variant == v), hasLength(1),
            reason: 'missing catalog entry for $v breaks isOnDisk()');
      }
    });

    test('verified sizes match the published model files', () async {
      final recs = await DeviceCapability.getRecommendations();
      final e2b = recs.firstWhere((r) => r.variant == ModelVariant.e2b);
      final e4b = recs.firstWhere((r) => r.variant == ModelVariant.e4b);
      // Exact Content-Length of each .litertlm from huggingface.co
      // (2026-07-16). A guessed size silently rejects complete downloads
      // because isOnDisk() applies a 99% floor against these numbers.
      expect(e2b.sizeBytes, 2588147712);
      expect(e4b.sizeBytes, 3659530240);
      expect(e2b.available, isTrue);
      expect(e4b.available, isTrue);
    });

    test('downloads the .litertlm build, never the web .task', () async {
      final recs = await DeviceCapability.getRecommendations();
      for (final r in recs.where((r) => r.available)) {
        // The repo's only .task is a raw-TFL3 WebAssembly build that the
        // Android engine cannot open; .litertlm is Gemma 4's Android path.
        expect(r.downloadUrl, endsWith('.litertlm'),
            reason: '${r.variant.name} must use the LiteRT-LM build');
        expect(r.downloadUrl, isNot(contains('-web.')));
      }
    });

    test('unverified 12B variant is not offered for download', () async {
      final recs = await DeviceCapability.getRecommendations();
      final twelveb =
          recs.firstWhere((r) => r.variant == ModelVariant.twelveb);
      expect(twelveb.available, isFalse);
      expect(twelveb.recommended, isFalse);
    });
  });

  group('DeviceCapability.formatBytesBn', () {
    test('formats across magnitudes', () {
      expect(DeviceCapability.formatBytesBn(512), '512 B');
      expect(DeviceCapability.formatBytesBn(2048), '2.0 KB');
      expect(DeviceCapability.formatBytesBn(5 * 1024 * 1024), '5.0 MB');
      expect(DeviceCapability.formatBytesBn(2003697664), '1.9 GB');
    });
  });
}
