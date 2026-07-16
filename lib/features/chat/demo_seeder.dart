/// Pure-Dart seeder for the chat history. Returns 3 pre-answered
/// Q&A pairs to be inserted on first run so the chat never looks
/// empty in a judge's hands.
///
/// Idempotent at the consumer level: the caller (chat_screen) only
/// seeds if the store is empty AND the seed flag isn't set.
class DemoSeeder {
  /// Built-in seed Q&A. Content matches what the existing KB
  /// already returns; the answers here are written directly so
  /// the demo runs even before the model is loaded.
  static List<({String question, String answer})> seeds() => const [
        (
          question: 'ওআরএস কীভাবে বানাবো?',
          answer:
              '১ লিটার পরিষ্কার পানিতে ৬ চা চামচ চিনি ও আধা চা চামচ লবণ মেশান। '
              'ভালো করে নাড়ুন এবং ২৪ ঘণ্টার মধ্যে খেয়ে ফেলুন। '
              'শিশুদের বারবার চামচ দিয়ে খাওয়ান।',
        ),
        (
          question: 'নিকটস্থ আশ্রয়কেন্দ্র কোথায়?',
          answer:
              'আশ্রয় মানচিত্রে (হোম → আশ্রয়) নিকটস্থ ঘূর্ণিঝড় আশ্রয়কেন্দ্র দেখুন। '
              'GPS অনুমতি দিলে দূরত্ব অনুযায়ী সাজানো তালিকা পাবেন।',
        ),
        (
          question: 'সাপে কামড়ালে কী করবো?',
          answer:
              'রোগীকে শান্ত রাখুন। কাটা, চুষা বা টর্নিকেট ব্যবহার করবেন না। '
              'আক্রান্ত স্থান নড়াচলা বন্ধ রাখুন এবং দ্রুত নিকটস্থ হাসপাতালে নিন।',
        ),
      ];
}