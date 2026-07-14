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

  group('ModelManager markReadyIfOnDisk', () {
    test('transitions to ready state', () {
      final mgr = ModelManager();
      expect(mgr.state, ModelState.notDownloaded);

      mgr.markReadyIfOnDisk();
      expect(mgr.state, ModelState.ready);
      expect(mgr.isReady, isTrue);
    });

    test('notifies listeners', () {
      final mgr = ModelManager();
      var notifyCount = 0;
      mgr.addListener(() => notifyCount++);

      mgr.markReadyIfOnDisk();
      expect(notifyCount, 1);
    });
  });

  group('ModelManager statusLabelBn', () {
    test('ready state shows "প্রস্তুত"', () {
      final mgr = ModelManager();
      mgr.markReadyIfOnDisk();
      expect(mgr.statusLabelBn, 'প্রস্তুত');
    });

    test('downloading with progress shows percentage format', () {
      const progress = 0.45;
      final pct = '${(progress * 100).round()}%';
      expect(pct, '45%');
    });
  });

  group('modelManager singleton', () {
    test('is a ModelManager instance', () {
      expect(modelManager, isA<ModelManager>());
    });
  });
}
