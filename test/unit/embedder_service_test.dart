import 'dart:typed_data';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/embedder_service.dart';

void main() {
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
