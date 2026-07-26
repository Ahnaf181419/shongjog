import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/cloud_ai/cloud_ai_service.dart';

/// The fixtures below are REAL responses captured from
/// `gemma-4-31b-it:generateContent` on 2026-07-25, not hand-written
/// approximations. Gemma on the Gemini REST API rejects
/// `thinkingConfig`, so its planning scratchpad cannot be suppressed at
/// the API level and streams into the response body — followed by the
/// actual answer, glued onto the tail of the final bullet with no
/// separator. These fixtures pin that exact shape.
void main() {
  group('CloudAiService.supportsThinkingConfig', () {
    test('is false for Gemma — the API 400s the whole request otherwise', () {
      expect(CloudAiService.supportsThinkingConfig('gemma-4-31b-it'), isFalse);
      expect(CloudAiService.supportsThinkingConfig('GEMMA-4-31B-IT'), isFalse,
          reason: 'Model ids should be matched case-insensitively.');
    });

    test('is true for Gemini models, which use it to hide their reasoning',
        () {
      expect(CloudAiService.supportsThinkingConfig('gemini-3.1-flash-lite'),
          isTrue);
      expect(CloudAiService.supportsThinkingConfig('gemini-2.0-flash'), isTrue);
    });

    test('both configured models accept thinkingConfig, so neither can leak '
        'reasoning into a user-facing emergency answer', () {
      expect(CloudAiService.supportsThinkingConfig(CloudAiService.primaryModelId),
          isTrue);
      expect(
          CloudAiService.supportsThinkingConfig(CloudAiService.fallbackModelId),
          isTrue);
    });

    test('no Gemma model is configured in the cloud chain — gemma-4-31b-it '
        'fails every call (400 with thinkingConfig, scratchpad leak without)',
        () {
      expect(CloudAiService.primaryModelId, isNot(startsWith('gemma')));
      expect(CloudAiService.fallbackModelId, isNot(startsWith('gemma')));
    });
  });

  group('CloudAiService.stripGemmaReasoning', () {
    test('recovers the answer glued to the last bullet after a danda', () {
      const raw = '''*   User asks: "বন্যার পানি নিরাপদ কিনা কিভাবে বুঝব?" (How do I know if flood water is safe?)
    *   Role: Bangla emergency assistant.
    *   Constraint 1: Answer only in simple Bangla.
    *   Constraint 2: Do not show reasoning.

    *   Flood water is generally *not* safe.
    *   It contains sewage, chemicals, and bacteria.
    *   পান করার আগে পানি অবশ্যই ফুটিয়ে বা বিশুদ্ধ করে নিন।বন্যার পানি সাধারণত নিরাপদ নয়। এতে ক্ষতিকর জীবাণু, ময়লা এবং রাসায়নিক মিশে থাকে।

পানি ঘোলা হলে, দুর্গন্ধ থাকলে বা ফেনা থাকলে তা একদম ব্যবহার করবেন না।''';

      final out = CloudAiService.stripGemmaReasoning(raw);
      expect(out, isNotNull);
      expect(out, startsWith('বন্যার পানি সাধারণত নিরাপদ নয়।'));
      expect(out, contains('পানি ঘোলা হলে'));
      expect(out, isNot(contains('User asks')),
          reason: 'The English scratchpad must not survive.');
      expect(out, isNot(contains('Constraint')));
      expect(out, isNot(contains('Flood water is generally')));
    });

    test('recovers a numbered answer glued after a Latin full stop', () {
      const raw = '''*   User input: "সাপে কামড়েছে, কি করবো?" (A snake has bitten, what should I do?)
    *   Role: Bangla emergency assistant.
    *   Stay calm.
    *   Simple Bangla? Yes.
    *   No reasoning? Yes.১. শান্ত থাকুন এবং আতঙ্কিত হবেন না।
২. আক্রান্ত স্থানটি একদম নাড়াচাড়া করবেন না, স্থির রাখুন।
৩. দ্রুত নিকটস্থ হাসপাতালে যান।''';

      final out = CloudAiService.stripGemmaReasoning(raw);
      expect(out, isNotNull);
      expect(out, startsWith('১. শান্ত থাকুন'));
      expect(out, contains('৩. দ্রুত নিকটস্থ হাসপাতালে যান।'));
      expect(out, isNot(contains('No reasoning?')));
      expect(out, isNot(contains('User input')));
    });

    test('leaves a clean answer untouched when there is no scratchpad', () {
      const clean =
          'বন্যার পানি কখনোই নিরাপদ নয়। পান করার আগে অবশ্যই ফুটিয়ে নিন।';
      expect(CloudAiService.stripGemmaReasoning(clean), clean);
    });

    test('does not mangle a genuine Bangla answer that uses markdown bullets '
        '— formatting alone must not be read as a scratchpad', () {
      const bulleted = '''*   শান্ত থাকুন।
*   দ্রুত হাসপাতালে যান।
*   ক্ষতস্থান কাটবেন না।''';
      expect(CloudAiService.stripGemmaReasoning(bulleted), bulleted,
          reason: 'Only a response OPENING with a Latin bullet is treated as '
              'a scratchpad; Bangla bullets are a legitimate answer format.');
    });

    test('returns null when a scratchpad is present but no answer can be '
        'recovered — the caller then falls through to the fallback model '
        'rather than showing the user raw English notes', () {
      const onlyNotes = '''*   User asks: something
    *   Role: assistant.
    *   Constraint: be brief.''';
      expect(CloudAiService.stripGemmaReasoning(onlyNotes), isNull);
    });

    test('returns null when the recovered fragment is too short to be a real '
        'answer', () {
      const raw = '''*   User asks: something
    *   Done.ঠিক।''';
      expect(CloudAiService.stripGemmaReasoning(raw), isNull);
    });
  });
}
