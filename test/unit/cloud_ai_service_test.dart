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

    test('both Gemini models accept thinkingConfig, so neither can leak '
        'reasoning into a user-facing emergency answer', () {
      expect(CloudAiService.supportsThinkingConfig(CloudAiService.primaryModelId),
          isTrue);
      expect(
          CloudAiService.supportsThinkingConfig(CloudAiService.fallbackModelId),
          isTrue);
    });

    test('Gemma is confined to the last-resort slot — a model that leaks its '
        'scratchpad must never be reached while a clean one is available', () {
      expect(CloudAiService.primaryModelId, isNot(startsWith('gemma')));
      expect(CloudAiService.fallbackModelId, isNot(startsWith('gemma')));
      expect(CloudAiService.lastResortModelId, startsWith('gemma'));
      expect(
          CloudAiService.supportsThinkingConfig(
              CloudAiService.lastResortModelId),
          isFalse,
          reason: 'If a future Gemma DID accept thinkingConfig it would no '
              'longer need the salvage path, and this ordering could be '
              'revisited.');
    });
  });

  group('CloudAiService.timeoutFor', () {
    test('gives Gemma a budget it can actually finish inside', () {
      // Measured live on 2026-07-29: gemma-4-26b-a4b-it took 19.3s and 13.0s
      // on two Bangla emergency prompts, because it generates its entire
      // scratchpad as visible tokens. The 10s budget the Gemini models use
      // would time it out on every call.
      final gemma = CloudAiService.timeoutFor(CloudAiService.lastResortModelId);
      expect(gemma.inSeconds, greaterThan(21),
          reason: 'Must exceed the slowest observed real response (21.2s).');
    });

    test('keeps the Gemini models on a short leash', () {
      expect(CloudAiService.timeoutFor(CloudAiService.primaryModelId),
          const Duration(seconds: 10));
      expect(CloudAiService.timeoutFor(CloudAiService.fallbackModelId),
          const Duration(seconds: 10));
    });

    test('the long budget is Gemma-specific, not a blanket raise', () {
      expect(
          CloudAiService.timeoutFor(CloudAiService.lastResortModelId),
          greaterThan(CloudAiService.timeoutFor(CloudAiService.primaryModelId)));
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

  // ── Real gemma-4-26b-a4b-it responses, captured 2026-07-29 ────────────
  //
  // Both were produced by the exact request this service sends (system
  // instruction + Bangla user turn, no thinkingConfig — the API 400s it).
  // They are kept verbatim because they document the two outcomes that
  // decide whether the last-resort tier is worth anything at all.
  group('CloudAiService.stripGemmaReasoning — live gemma-4-26b-a4b-it', () {
    test('recovers the final answer when Gemma drafts, self-checks, then '
        'restates cleanly at the end', () {
      const raw = '''

*   Topic: What to do during a cyclone (ঘূর্ণিঝড়ের সময় কী করব?).
*   Constraint 1: Concise (সংক্ষেপে বলো).
*   Constraint 2: Persona: Shongjog (Bangla-first emergency companion).
*   Constraint 3: Language: Bangla.

    *   Before/During the onset:
        *   Move to a shelter.
        *   Stay away from windows/doors.
        *   Switch off electricity/gas.
        *   Keep an emergency kit ready.
        *   Avoid going outside.
        *   Stay tuned to news/radio.

    *   *Draft 1 (Mental):* ঘূর্ণিঝড়ের সময় নিরাপদ আশ্রয়ে থাকুন। জানলা থেকে দূরে থাকুন। বিদ্যুৎ ও গ্যাস বন্ধ করুন। রেডিও শুনুন। বাইরে যাবেন না।

    *   *Draft 2 (Adding structure and tone):*
        ১. দ্রুত নিরাপদ আশ্রয়ে বা সাইক্লোন শেল্টারে চলে যান।
        ২. জানলা ও দরজা বন্ধ রাখুন এবং কাঁচের জিনিস থেকে দূরে থাকুন।
        ৩. বিদ্যুৎ ও গ্যাসের সংযোগ বিচ্ছিন্ন করুন।
        ৪. জরুরি খাবার, পানি ও টর্চলাইট সাথে রাখুন।
        ৫. রেডিও বা খবরের মাধ্যমে সতর্কবার্তা শুনুন।
        ৬. বিপদ না কাটলে বাইরে বের হবেন না।

    *   *Refining for "Shongjog" persona (Empathetic but direct):*
        ঘূর্ণিঝড়ের সময় নিজেকে ও পরিবারকে সুরক্ষিত রাখতে এই কাজগুলো করুন:

        ১. **নিরাপদ আশ্রয়ে যান:** দ্রুত সাইক্লোন শেল্টার বা মজবুত ঘরে আশ্রয় নিন।
        ২. **জানলা থেকে দূরে থাকুন:** কাঁচের জানলা বা দরজা থেকে দূরে নিরাপদ স্থানে থাকুন।
        ৩. **বিদ্যুৎ ও গ্যাস বন্ধ করুন:** শর্ট সার্কিট বা অগ্নিকাণ্ড এড়াতে মেইন সুইচ বন্ধ রাখুন।
        ৪. **জরুরি কিট সাথে রাখুন:** টর্চলাইট, শুকনো খাবার, পানি এবং প্রাথমিক চিকিৎসার সরঞ্জাম কাছে রাখুন।
        ৫. **বাইরে যাবেন না:** বাতাস ও বৃষ্টি কমলেও বিপদ না সারা পর্যন্ত বাইরে বের হবেন না।
        ৬. **খবর শুনুন:** রেডিও বা ফোনের মাধ্যমে সরকারি সতর্কবার্তা অনুসরণ করুন।

    *   Bangla-first? Yes.
    *   Concise? Yes.
    *   Emergency context? Yes.

    ঘূর্ণিঝড়ের সময় সুরক্ষিত থাকতে নিচের পদক্ষেপগুলো নিন:

    ১. **নিরাপদ আশ্রয়ে যান:** দ্রুত সাইক্লোন শেল্টার বা মজবুত ঘরে আশ্রয় নিন।
    ২. **জানলা থেকে দূরে থাকুন:** কাঁচের জানলা বা দরজা থেকে দূরে নিরাপদ স্থানে থাকুন।
    ৩. **বিদ্যুৎ ও গ্যাস বন্ধ করুন:** শর্ট সার্কিট বা অগ্নিকাণ্ড এড়াতে মেইন সুইচ ও গ্যাসের সংযোগ বিচ্ছিন্ন করুন।
    ৪. **জরুরি সরঞ্জাম সাথে রাখুন:** টর্চলাইট, শুকনো খাবার, পানি এবং জরুরি ওষুধ কাছে রাখুন।
    ৫. **বাইরে বের হবেন না:** বিপদ পুরোপুরি না কমা পর্যন্ত ঘরের বাইরে যাবেন না।
    ৬. **সতর্কবার্তা শুনুন:** রেডিও বা ফোনের মাধ্যমে সরকারি খবরের দিকে নজর রাখুন।

    সাবধান থাকুন, নিরাপদ থাকুন।''';

      final out = CloudAiService.stripGemmaReasoning(raw);

      expect(out, isNotNull);
      // The English planning notes and BOTH interim drafts must be gone.
      expect(out, isNot(contains('Constraint 1')));
      expect(out, isNot(contains('Draft 1')));
      expect(out, isNot(contains('Draft 2')));
      expect(out, isNot(contains('Refining for')));
      expect(out, isNot(contains('Bangla-first?')));
      expect(out, isNot(contains('Move to a shelter')));
      // ...and the real Bangla answer must survive intact.
      expect(out, startsWith('ঘূর্ণিঝড়ের সময় সুরক্ষিত থাকতে'));
      expect(out, contains('সাইক্লোন শেল্টার'));
      expect(out, endsWith('সাবধান থাকুন, নিরাপদ থাকুন।'));
    });

    test('returns null when the response is scratchpad end-to-end, so the '
        'user sees the no-answer string instead of English planning notes',
        () {
      // This response never restates its answer outside the bullets — the
      // Bangla exists only quoted INSIDE a draft bullet, and the response
      // then ends on self-check notes. Salvaging it would mean guessing.
      const raw = '''

*   User Question: "বন্যার পানিতে আটকা পড়লে কী করব?" (What should I do if trapped in floodwater?)
*   Persona: Shongjog (Bangla-first emergency companion).
*   Constraint: Answer in Bangla, concisely.

    *   Immediate safety (high ground).
    *   Avoid moving water/currents.
    *   Electricity safety (avoid wires/poles).
    *   Communication (help/emergency numbers).
    *   Supplies (food/water/medication).
    *   Hygiene/Health (clean water/preventing disease).

    *   *Point 1: High Ground.* উঁচু স্থানে আশ্রয় নিন। (Take shelter in a high place.)
    *   *Point 2: Avoid Current.* স্রোতযুক্ত পানিতে নামবেন না। (Don't enter flowing water.)
    *   *Point 3: Electricity.* বৈদ্যুতিক খুঁটি বা তার থেকে দূরে থাকুন। (Stay away from electric poles/wires.)
    *   *Point 4: Communication.* জরুরি নম্বর বা স্থানীয় প্রশাসনকে জানান। (Inform emergency numbers or local administration.)
    *   *Point 5: Supplies.* শুকনো খাবার ও বিশুদ্ধ পানি সাথে রাখুন। (Keep dry food and pure water with you.)

    *   "বন্যার পানিতে আটকা পড়লে নিচের পদক্ষেপগুলো নিন:
        ১. দ্রুত উঁচু স্থানে বা ছাদের ওপর আশ্রয় নিন।
        ২. স্রোত বা পানির তীব্র প্রবাহে নামার চেষ্টা করবেন না।
        ৩. বৈদ্যুতিক খুঁটি, তার বা ইলেকট্রিক সুইচ থেকে দূরে থাকুন।
        ৪. শুকনো খাবার, বিশুদ্ধ পানি এবং জরুরি ওষুধ সাথে রাখুন।
        ৫. সাহায্যের জন্য স্থানীয় প্রশাসন বা জরুরি নম্বরে যোগাযোগ করুন।"

    *   Bangla-first? Yes.
    *   Concise? Yes.
    *   Emergency persona? Yes.''';

      expect(CloudAiService.stripGemmaReasoning(raw), isNull);
    });
  });


}
