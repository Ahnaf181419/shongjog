import 'package:flutter/foundation.dart';
import 'intelligence_engine.dart';
import 'user_profile.dart';

class ProactiveInsight {
  final String title;
  final String message;
  final String route;
  
  const ProactiveInsight({
    required this.title,
    required this.message,
    required this.route,
  });
}

class NotificationService {
  /// Generates context-aware, proactive notifications based on local behavior.
  static List<ProactiveInsight> generateInsights(UserProfile profile) {
    final insights = <ProactiveInsight>[];

    if (profile.showsCycloneInterest) {
      insights.add(const ProactiveInsight(
        title: 'ঘূর্ণিঝড় প্রস্তুতি',
        message: 'আপনার নিকটবর্তী আশ্রয়কেন্দ্র আগে থেকেই ম্যাপে দেখে রাখুন।',
        route: '/shelter',
      ));
    }

    if (profile.showsFloodInterest) {
      insights.add(const ProactiveInsight(
        title: 'বন্যা সতর্কতা',
        message: 'পানি বিশুদ্ধ করার নিয়মগুলো জেনে নিন।',
        route: '/cards',
      ));
    }

    if (profile.showsMedicalInterest) {
      insights.add(const ProactiveInsight(
        title: 'চিকিৎসা সহায়তা',
        message: 'ORS তৈরির নিয়ম এবং জরুরি যোগাযোগ প্রস্তুত রাখুন।',
        route: '/cards',
      ));
    }

    // Default insight if no specific interests
    if (insights.isEmpty) {
      insights.add(const ProactiveInsight(
        title: 'অফলাইন AI প্রস্তুত',
        message: 'ইন্টারনেট ছাড়াই শঙ্গ্যোগ আপনার প্রশ্নের উত্তর দিতে পারে।',
        route: '/',
      ));
    }

    return insights;
  }
}
