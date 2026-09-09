import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shongjog/rag/embedder.dart';

/// Stand-in for the plugin's embedder — records what it was asked and
/// returns a fixed vector, so [EmbedderImpl] logic is tested without
/// platform channels.
class _FakeGemmaEmbeddingModel implements EmbeddingModel {
  _FakeGemmaEmbeddingModel(this.vector);

  final List<double> vector;
  TaskType? lastTaskType;
  String? lastText;

  @override
  Future<List<double>> generateEmbedding(
    String text, {
    TaskType taskType = TaskType.retrievalQuery,
  }) async {
    lastText = text;
    lastTaskType = taskType;
    return vector;
  }

  @override
  Future<List<List<double>>> generateEmbeddings(
    List<String> texts, {
    TaskType taskType = TaskType.retrievalQuery,
  }) async =>
      [for (final _ in texts) vector];

  @override
  Future<int> getDimension() async => vector.length;

  @override
  void addCloseListener(void Function() listener) {}

  @override
  Future<void> close() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('EmbedderImpl.normalize', () {
    test('scales a vector to unit length', () {
      final v = Float32List.fromList([3.0, 4.0]);
      final n = EmbedderImpl.normalize(v);
      expect(n.length, 2);
      expect(n[0], closeTo(0.6, 1e-6));
      expect(n[1], closeTo(0.8, 1e-6));
    });

    test('already-unit vector is returned unchanged', () {
      // [1, 0] is exactly unit in float32 (0.6/0.8 are not, so their
      // norm lands epsilon off 1.0 and legitimately re-normalizes).
      final v = Float32List.fromList([1.0, 0.0]);
      final n = EmbedderImpl.normalize(v);
      expect(identical(n, v), isTrue);
    });

    test('zero vector stays zero (no NaN from 0/0)', () {
      final n = EmbedderImpl.normalize(Float32List.fromList([0.0, 0.0]));
      expect(n[0], 0.0);
      expect(n[1], 0.0);
      expect(n[0].isNaN, isFalse);
    });
  });

  group('EmbedderImpl', () {
    test('embed returns an L2-normalized Float32List', () async {
      final fake = _FakeGemmaEmbeddingModel([3.0, 4.0]);
      final embedder = EmbedderImpl(fake);
      final v = await embedder.embed('ডায়রিয়ায় কী করবো');
      expect(v, isA<Float32List>());
      expect(v[0], closeTo(0.6, 1e-6));
      expect(v[1], closeTo(0.8, 1e-6));
    });

    test('default task is retrievalQuery', () async {
      final fake = _FakeGemmaEmbeddingModel([1.0]);
      await EmbedderImpl(fake).embed('q');
      expect(fake.lastTaskType, TaskType.retrievalQuery);
    });

    test('document task maps to retrievalDocument', () async {
      final fake = _FakeGemmaEmbeddingModel([1.0]);
      await EmbedderImpl(fake).embed('doc', task: EmbedTask.document);
      expect(fake.lastTaskType, TaskType.retrievalDocument);
    });

    test('text passes through to the plugin unmodified', () async {
      final fake = _FakeGemmaEmbeddingModel([1.0]);
      await EmbedderImpl(fake).embed('ORS বানানো');
      expect(fake.lastText, 'ORS বানানো');
    });
  });
}
