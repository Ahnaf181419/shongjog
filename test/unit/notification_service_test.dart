import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/intelligence/notification_service.dart';
import 'package:shongjog/features/intelligence/user_profile.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppLocalizations> loadBn() =>
      AppLocalizations.delegate.load(const Locale('bn'));
  Future<AppLocalizations> loadEn() =>
      AppLocalizations.delegate.load(const Locale('en'));

  group('NotificationService.generateInsights', () {
    test('empty profile yields exactly the default insight', () async {
      final l10n = await loadBn();
      final insights = NotificationService.generateInsights(
        UserProfile.empty(),
        l10n: l10n,
      );
      expect(insights, hasLength(1));
      expect(insights.first.title, 'অফলাইন AI প্রস্তুত');
    });

    test('cyclone interest yields shelter preparation insight', () async {
      final l10n = await loadBn();
      final profile = UserProfile(
        topicFrequencies: const {'cyclone': 3},
        recentSearches: const ['ঘূর্ণিঝড় আসছে কি করবো'],
        lastActiveTime: DateTime(2026, 7, 15),
      );
      final insights = NotificationService.generateInsights(profile, l10n: l10n);
      expect(insights.map((i) => i.title), contains('ঘূর্ণিঝড় প্রস্তুতি'));
      expect(
        insights.map((i) => i.title),
        isNot(contains('অফলাইন AI প্রস্তুত')),
      );
    });

    test('medical interest yields medical insight routed to cards', () async {
      final l10n = await loadBn();
      final profile = UserProfile(
        topicFrequencies: const {'medical': 2},
        recentSearches: const ['ডায়রিয়া হলে কি করবো'],
        lastActiveTime: DateTime(2026, 7, 15),
      );
      final insights = NotificationService.generateInsights(profile, l10n: l10n);
      final medical =
          insights.firstWhere((i) => i.title == 'চিকিৎসা সহায়তা');
      expect(medical.route, '/cards');
    });

    test('English locale yields English copy', () async {
      final l10n = await loadEn();
      final insights = NotificationService.generateInsights(
        UserProfile.empty(),
        l10n: l10n,
      );
      expect(insights.first.title, 'Offline AI ready');
      expect(insights.first.message, contains('internet'));
    });

    test('Bangla locale yields Bangla copy', () async {
      final l10n = await loadBn();
      final insights = NotificationService.generateInsights(
        UserProfile.empty(),
        l10n: l10n,
      );
      expect(insights.first.title, 'অফলাইন AI প্রস্তুত');
      expect(insights.first.message, contains('ইন্টারনেট'));
    });
  });
}
