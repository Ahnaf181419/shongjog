import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/intelligence/notification_service.dart';
import 'package:shongjog/features/intelligence/user_profile.dart';

void main() {
  group('NotificationService.generateInsights', () {
    test('empty profile yields exactly the default insight', () {
      final insights = NotificationService.generateInsights(UserProfile.empty());
      expect(insights, hasLength(1));
      expect(insights.first.title, 'অফলাইন AI প্রস্তুত');
    });

    test('cyclone interest yields shelter preparation insight', () {
      final profile = UserProfile(
        topicFrequencies: const {'cyclone': 3},
        recentSearches: const ['ঘূর্ণিঝড় আসছে কি করবো'],
        lastActiveTime: DateTime(2026, 7, 15),
      );
      final insights = NotificationService.generateInsights(profile);
      expect(insights.map((i) => i.title), contains('ঘূর্ণিঝড় প্রস্তুতি'));
      expect(insights.map((i) => i.title), isNot(contains('অফলাইন AI প্রস্তুত')));
    });

    test('medical interest yields medical insight routed to cards', () {
      final profile = UserProfile(
        topicFrequencies: const {'medical': 2},
        recentSearches: const ['ডায়রিয়া হলে কি করবো'],
        lastActiveTime: DateTime(2026, 7, 15),
      );
      final insights = NotificationService.generateInsights(profile);
      final medical =
          insights.firstWhere((i) => i.title == 'চিকিৎসা সহায়তা');
      expect(medical.route, '/cards');
    });
  });
}
