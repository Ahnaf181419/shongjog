import '../../l10n/app_localizations.dart';
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
  ///
  /// All user-facing copy is sourced from [AppLocalizations] — call this with
  /// `AppLocalizations.of(context)` from the BuildContext that owns the
  /// notification surface.
  static List<ProactiveInsight> generateInsights(
    UserProfile profile, {
    required AppLocalizations l10n,
  }) {
    final insights = <ProactiveInsight>[];

    if (profile.showsCycloneInterest) {
      insights.add(ProactiveInsight(
        title: l10n.insightCycloneTitle,
        message: l10n.insightCycloneBody,
        route: '/shelter',
      ));
    }

    if (profile.showsFloodInterest) {
      insights.add(ProactiveInsight(
        title: l10n.insightFloodTitle,
        message: l10n.insightFloodBody,
        route: '/cards',
      ));
    }

    if (profile.showsMedicalInterest) {
      insights.add(ProactiveInsight(
        title: l10n.insightMedicalTitle,
        message: l10n.insightMedicalBody,
        route: '/cards',
      ));
    }

    // Default insight if no specific interests
    if (insights.isEmpty) {
      insights.add(ProactiveInsight(
        title: l10n.insightOfflineTitle,
        message: l10n.insightOfflineBody,
        route: '/',
      ));
    }

    return insights;
  }
}

/// Helper: drop-in replacement when callers don't have an [AppLocalizations]
/// in scope (e.g. tests). Falls back to Bangla — matches the historical
/// behaviour before this service was i18n'd.
extension NotificationServiceBanglaFallback on NotificationService {
  static List<ProactiveInsight> generateInsightsBn(UserProfile profile) {
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
