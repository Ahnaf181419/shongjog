import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/embedder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('EmbedderService lifecycle', () {
    test('refreshStatus reports ready when hasActive is true', () async {
      final svc = EmbedderService(hasActive: () => true);
      await svc.refreshStatus();
      expect(svc.status, EmbedderStatus.ready);
      expect(svc.error, isNull);
    });

    test('refreshStatus reports notInstalled when hasActive is false',
        () async {
      final svc = EmbedderService(hasActive: () => false);
      await svc.refreshStatus();
      expect(svc.status, EmbedderStatus.notInstalled);
      expect(svc.error, isNull);
    });

    test('refreshStatus catches plugin exceptions into status=unknown',
        () async {
      final svc = EmbedderService(hasActive: () => throw StateError('boom'));
      await svc.refreshStatus();
      expect(svc.status, EmbedderStatus.unknown);
      expect(svc.error, contains('boom'));
    });

    test('createEmbedder returns null when nothing is installed', () async {
      final svc = EmbedderService(hasActive: () => false);
      expect(await svc.createEmbedder(), isNull);
    });

    test('createEmbedder returns null on plugin getActive failure', () async {
      final svc = EmbedderService(
        hasActive: () => true,
        getActive: () async => throw StateError('model file corrupt'),
      );
      expect(await svc.createEmbedder(), isNull);
    });

    test('createEmbedder returns a real Embedder when both hooks succeed',
        () async {
      final fakeModel = _FakeEmbeddingModel(Float32List(768));
      final svc = EmbedderService(
        hasActive: () => true,
        getActive: () async => fakeModel,
      );
      final embedder = await svc.createEmbedder();
      expect(embedder, isNotNull);
      expect(await embedder!.dim(), 768);
    });

    test('notifies listeners on every refreshStatus', () async {
      var calls = 0;
      final svc = EmbedderService(hasActive: () => false)
        ..addListener(() => calls++);
      await svc.refreshStatus();
      await svc.refreshStatus();
      expect(calls, 2);
    });

    test('source defaults to the compile-time EMBEDDER_SOURCE define',
        () async {
      // No --dart-define in tests; should default to network.
      expect(kDefaultEmbedderSource, EmbedderSource.network);
      expect(EmbedderService().source, EmbedderSource.network);
    });

    test('source can be overridden to asset for prebuilt APKs', () async {
      final svc = EmbedderService(source: EmbedderSource.asset);
      expect(svc.source, EmbedderSource.asset);
    });
  });

  // Guards the prebuilt-APK asset-install path. flutter_gemma's
  // AssetSourceHandler delegates to the native large_file_handler plugin,
  // which resolves the asset via FlutterLoader.getLookupKeyForAsset — and
  // that only knows assets listed in pubspec.yaml's flutter.assets. Files
  // sitting under android/app/src/main/assets/ but NOT declared in pubspec
  // made install() throw "Asset key not found" (surfaced as IOException),
  // which the startup warmup swallowed, leaving the Settings row stuck on
  // "off" with no visible error (see commit history for the field report).
  group('prebuilt asset declarations', () {
    test('kEmbedderAsset paths are declared in pubspec.yaml flutter.assets',
        () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspec,
        contains('- assets/embeddinggemma/'),
        reason: 'tool/bundle_embedder.py writes to assets/embeddinggemma/ '
            'but pubspec.yaml does not list it under flutter.assets — '
            'getLookupKeyForAsset() will throw and the prebuilt APK '
            'install() will fail silently.',
      );
    });

    test('bundled model files exist on disk when the bundle script has run',
        () {
      // "Script has run" = at least one payload present. The dir itself is
      // NOT the signal — it always exists on a fresh checkout (committed
      // .gitkeep) — and a standard checkout has neither payload, which must
      // skip rather than fail. A partial bundle (one payload present, the
      // other missing) is exactly the corruption this test exists to catch.
      final hasModel =
          File('assets/embeddinggemma/model.tflite').existsSync();
      final hasTokenizer =
          File('assets/embeddinggemma/sentencepiece.model').existsSync();
      if (!hasModel && !hasTokenizer) return; // standard checkout — skip.
      expect(hasModel, isTrue,
          reason: 'sentencepiece.model is present under '
              'assets/embeddinggemma/ but model.tflite is missing — '
              're-run tool/bundle_embedder.py.');
      expect(hasTokenizer, isTrue,
          reason: 'model.tflite is present under '
              'assets/embeddinggemma/ but sentencepiece.model is missing — '
              're-run tool/bundle_embedder.py.');
    });
  });
}

class _FakeEmbeddingModel implements EmbeddingModel {
  _FakeEmbeddingModel(this.vector);
  final Float32List vector;
  @override
  Future<List<double>> generateEmbedding(String text,
          {TaskType taskType = TaskType.retrievalQuery}) async =>
      vector.toList();
  @override
  Future<List<List<double>>> generateEmbeddings(List<String> texts,
          {TaskType taskType = TaskType.retrievalQuery}) async =>
      texts.map((_) => vector.toList()).toList();
  @override
  Future<int> getDimension() async => vector.length;
  @override
  void addCloseListener(void Function() listener) {}
  @override
  Future<void> close() async {}
}
