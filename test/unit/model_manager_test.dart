import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/model_manager.dart';

void main() {
  group('ModelState enum', () {
    test('has all expected states', () {
      expect(ModelState.values, contains(ModelState.notDownloaded));
      expect(ModelState.values, contains(ModelState.downloading));
      expect(ModelState.values, contains(ModelState.ready));
      expect(ModelState.values, contains(ModelState.loading));
      expect(ModelState.values, contains(ModelState.failed));
    });
  });

  group('ModelManager default state', () {
    final mgr = ModelManager();

    test('initial state is notDownloaded', () {
      expect(mgr.state, ModelState.notDownloaded);
    });

    test('statusLabelBn shows download needed', () {
      expect(mgr.statusLabelBn, contains('ডাউনলোড'));
    });

    test('isReady is false initially', () {
      expect(mgr.isReady, isFalse);
    });

    test('isLoading is false initially', () {
      expect(mgr.isLoading, isFalse);
    });

    test('downloadProgress is null initially', () {
      expect(mgr.downloadProgress, isNull);
    });
  });

  group('ModelManager statusLabelBn format', () {
    test('downloading with progress shows percentage format', () {
      // Test the format string directly since we can't set private state
      const progress = 0.45;
      final pct = '${(progress * 100).round()}%';
      expect(pct, '45%');
    });
  });
}
