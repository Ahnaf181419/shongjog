import 'package:flutter/material.dart';

/// Static emergency quick card data. No model dependency — these render
/// instantly even if Gemma fails to load (safety net, docs/prd.md M4).
class QuickCard {
  final String id;
  final String titleBn;
  final IconData icon;
  final Color color;
  final List<String> stepsBn;

  const QuickCard({
    required this.id,
    required this.titleBn,
    required this.icon,
    required this.color,
    required this.stepsBn,
  });
}

const kQuickCards = <QuickCard>[
  QuickCard(
    id: 'ors',
    titleBn: 'ORS তৈরি',
    icon: Icons.water_drop_outlined,
    color: Color(0xFF0E5E6F),
    stepsBn: [
      '১ লিটার পরিষ্কার পানি নিন',
      '৬ চা-চামচ চিনি ও আধা চা-চামচ লবণ মেশান',
      'ভালো করে নাড়ুন যতক্ষণ না দ্রবীভূত হয়',
      'একটু একটু করে বারবার খাওয়ান',
      'বানানো ORS কয়েক ঘণ্টা পর নতুন করে বানান',
    ],
  ),
  QuickCard(
    id: 'water',
    titleBn: 'পানি শুদ্ধ করা',
    icon: Icons.opacity,
    color: Color(0xFF0E5E6F),
    stepsBn: [
      'পানি ফুটিয়ে নিন (কমপক্ষে ১ মিনিট)',
      'ফুটানো সম্ভব না হলে পরিষ্কার কাপড়ে ছেঁকে নিন',
      'স্বচ্ছ প্লাস্টিক বোতলে ৬ ঘণ্টা রোদে রাখুন',
      'ORS-এর জন্য এই পানি ব্যবহার করুন',
    ],
  ),
  QuickCard(
    id: 'snakebite',
    titleBn: 'সাপের কামড়',
    icon: Icons.warning_amber_outlined,
    color: Color(0xFFDC2626),
    stepsBn: [
      'কাটবেন না, চুষবেন না, বরফ দেবেন না',
      'আক্রান্ত স্থান নিচু রাখুন ও নড়াচড়া কমান',
      'শিকারকে শান্ত রাখুন — দৌড় নয়',
      'দ্রুত নিকটস্থ হাসপাতালে যান',
      'জরুরি হলে ৯৯৯ এ কল করুন',
    ],
  ),
  QuickCard(
    id: 'diarrhea',
    titleBn: 'প্রচণ্ড ডায়রিয়া',
    icon: Icons.healing_outlined,
    color: Color(0xFFDC2626),
    stepsBn: [
      'বারবার ORS খাওয়ান',
      'প্রতিবার পাতলা পায়খানার পর ১ গ্লাস পানিঝুলি',
      'শিশু বমি করলে অল্প অল্প করে বারবার দিন',
      'রক্ত মিশ্রিত বা ২৪ ঘণ্টার বেশি হলে ডাক্তার দেখান',
    ],
  ),
  QuickCard(
    id: 'shelter',
    titleBn: 'আশ্রয়কেন্দ্র',
    icon: Icons.shield_outlined,
    color: Color(0xFF0E5E6F),
    stepsBn: [
      'নিকটস্থ সাইক্লোন শেল্টারে যান',
      'খাবার ও পানি সঙ্গে রাখুন (৩ দিনের)',
      'মূল্যবান কাগজপত্র সঙ্গে নিন',
      'গাছ ও বৈদ্যুতিক খুঁটি থেকে দূরে থাকুন',
    ],
  ),
  QuickCard(
    id: 'bleeding',
    titleBn: 'রক্তপাত বন্ধ',
    icon: Icons.medical_services_outlined,
    color: Color(0xFFDC2626),
    stepsBn: [
      'পরিষ্কার কাপড় দিয়ে জায়গায় চাপ দিন',
      'আক্রান্ত অংশ হৃদয়ের চেয়ে উঁচুতে রাখুন',
      '১০ মিনিট ধরে চাপ অব্যাহত রাখুন',
      'না থামলে ৯৯৯ এ কল করুন',
    ],
  ),
  QuickCard(
    id: 'fever',
    titleBn: 'জ্বর হলে করণীয়',
    icon: Icons.thermostat_outlined,
    color: Color(0xFFDC2626),
    stepsBn: [
      'প্রচুর পানি ও তরল খাওয়ান',
      'হালকা ঢিলেঢালা কাপড় পরুন',
      'প্যারাসিটামল সঠিক ডোজে দিন (বয়স অনুযায়ী)',
      'কপালে ও বগলে ঠাণ্ডা পানির সেঁক দিন',
      '৩ দিনের বেশি জ্বর বা ১০২°F উপরে হলে ডাক্তার দেখান',
      'শিশুর দাঁড়ি-ঝাড়া খিঁচুনি বা অজ্ঞান হলে ৯৯৯ কল করুন',
    ],
  ),
  QuickCard(
    id: 'drowning',
    titleBn: 'ডুবে যাওয়া ব্যক্তি',
    icon: Icons.pool_outlined,
    color: Color(0xFF0E5E6F),
    stepsBn: [
      'নিজে পানিতে নামবেন না — দড়ি বা লাঠি দিয়ে টানুন',
      'সাঁতার না জানলে কখনো পানিতে ঝাঁপাবেন না',
      'ব্যক্তিকে পানির বাইরে টেনে আনুন',
      'নাকে-মুখে পানি থাকলে গায়ের ওপর চাপ দিন',
      'শ্বাস না নিলে ৩০ সেকেন্ড CPR দিন',
      'দ্রুত ৯৯৯ এ কল করুন',
    ],
  ),
];