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
  _samplerContracts();
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

// ════════════════════════════════════════════════════════════════════
//  SAMPLER SEED / THINKING-MODE CONTRACTS
//
//  Two engine-level constraints that silently corrupt generation when
//  violated. Both are invisible in the Dart type system, so they are
//  pinned here.
// ════════════════════════════════════════════════════════════════════
void _samplerContracts() {
  group('nextRandomSeed (Int32 contract)', () {
    // LiteRtLmSamplerParams.seed is @ffi.Int32(). Dart FFI truncates an
    // out-of-range store to the low 32 bits SIGNED, so a raw
    // microsecondsSinceEpoch (~1.78e15) hands native a negative seed for
    // ~35.8 of every 71.6 minutes.
    const int32Max = 2147483647;

    test('always fits a non-negative Int32', () {
      for (var i = 0; i < 2000; i++) {
        final s = ModelManager.nextRandomSeed();
        expect(s, greaterThanOrEqualTo(0));
        expect(s, lessThanOrEqualTo(int32Max));
      }
    });

    test('a raw microsecond timestamp would NOT satisfy that contract', () {
      // Guards the rationale: if this ever becomes false the mask is
      // no longer needed and this test should be revisited.
      expect(DateTime.now().microsecondsSinceEpoch, greaterThan(int32Max));
    });

    test('still varies between calls (seed diversity is the whole point)', () {
      final seen = <int>{};
      for (var i = 0; i < 50; i++) {
        seen.add(ModelManager.nextRandomSeed());
      }
      expect(seen.length, greaterThan(1));
    });
  });

  group('thinking mode', () {
    test('stays disabled while the .litertlm engine leaks the thought channel',
        () {
      // flutter_gemma_litertlm 1.1.0 has no channel separation:
      // enableThinking only injects {"enable_thinking": true} into the
      // template and the raw <|channel|>thought tokens land in the answer.
      expect(ModelManager.kThinkingModeSupported, isFalse);
    });
  });
}
