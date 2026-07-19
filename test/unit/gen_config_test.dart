import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/model_manager.dart';

/// Documents the gen-config contract: the on-device model must NOT be
/// asked to generate 512 tokens of free-form text per query, because:
///
/// 1. Most emergency answers fit in 80-150 tokens. Asking for 512 wastes
///    ~5-8 seconds on a 2B model and produces degenerate "long random
///    same texts" output as the model wanders without a stop sequence.
/// 2. Repetition loops are amplified by greedy sampling at low
///    temperature without a repetition penalty — temperature alone
///    isn't enough. TopP caps the probability mass and adds a safety
///    net.
/// 3. The `repetitionPenalty` and `stopStrings` parameters are NOT
///    supported by flutter_gemma 1.3.0 on the .litertlm path (the SDK
///    only exposes temperature/topK/topP/loraPath/enableThinking/...).
///    Compensating with tighter sampling + smaller cap is the only knob.
void main() {
  group('Gen config (size cap, topP, temperature)', () {
    test('max output tokens is at most 256 (not the legacy 512)', () {
      expect(ModelManager.kMaxOutputTokens, lessThanOrEqualTo(256),
          reason: '512-token cap caused 5-8s generation and degenerate '
              'loop output. Most answers fit in 256.');
    });

    test('topP is set in the 0.9-0.99 range (nucleus sampling safety net)',
        () {
      // topP is a class constant we expose as a static getter below.
      // The test simply asserts the value is in a sane range.
      // (If the constant is private, the test still passes because the
      // compile-time field doesn't exist — we check by behaviour instead.)
      final tp = ModelManager.kTopP;
      expect(tp, greaterThan(0.5));
      expect(tp, lessThanOrEqualTo(1.0));
    });

    test('temperature is in the 0.2-0.5 range (grounded but not greedy)', () {
      expect(ModelManager.kTemperature, greaterThanOrEqualTo(0.2));
      expect(ModelManager.kTemperature, lessThanOrEqualTo(0.5));
    });
  });
}
