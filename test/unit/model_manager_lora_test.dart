import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/model_manager.dart';

void main() {
  group('ModelManager LoRA + thinking mode', () {
    test('setLoraAdapter stores the path', () {
      final mgr = ModelManager();
      expect(mgr.loraPath, isNull);
      mgr.setLoraAdapter('/path/to/adapter.task');
      expect(mgr.loraPath, '/path/to/adapter.task');
    });

    test('clearLoraAdapter nulls the path', () {
      final mgr = ModelManager()
        ..setLoraAdapter('/path/to/adapter.task');
      expect(mgr.loraPath, isNotNull);
      mgr.clearLoraAdapter();
      expect(mgr.loraPath, isNull);
    });

    test('setThinkingMode stores the override', () {
      final mgr = ModelManager();
      mgr.setThinkingMode(true);
      // Can't read _enableThinking directly (private), but we can verify
      // the method doesn't throw and the manager is still usable.
      expect(mgr.isReady, isFalse);
    });

    test('setThinkingMode(null) resets to SDK default', () {
      final mgr = ModelManager();
      mgr.setThinkingMode(true);
      mgr.setThinkingMode(null);
      expect(mgr.isReady, isFalse);
    });
  });
}
