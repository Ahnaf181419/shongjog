import 'package:flutter/foundation.dart';
import '../chat/chat_store.dart';
import 'user_profile.dart';

class IntelligenceEngine extends ChangeNotifier {
  UserProfile _profile = UserProfile.empty();
  UserProfile get profile => _profile;

  final ChatStore _chatStore = ChatStore();

  /// Analyzes local chat history to build a user profile silently.
  /// No data is sent to the cloud.
  Future<void> analyzeBehavior() async {
    try {
      final messages = await _chatStore.load();
      if (messages.isEmpty) return;

      final userQueries = messages
          .where((m) => m.isUser)
          .map((m) => m.text)
          .toList();

      final recent = userQueries.take(10).toList();
      final topicFreqs = <String, int>{};

      for (final query in userQueries) {
        if (query.contains('ঘূর্ণিঝড়') || query.contains('সাইক্লোন')) {
          topicFreqs['cyclone'] = (topicFreqs['cyclone'] ?? 0) + 1;
        }
        if (query.contains('আশ্রয়') || query.contains('শেল্টার')) {
          topicFreqs['shelter'] = (topicFreqs['shelter'] ?? 0) + 1;
        }
        if (query.contains('বন্যা') || query.contains('পানি')) {
          topicFreqs['flood'] = (topicFreqs['flood'] ?? 0) + 1;
        }
        if (query.contains('ডায়রিয়া') || query.contains('সাপে') || query.contains('জ্বর')) {
          topicFreqs['medical'] = (topicFreqs['medical'] ?? 0) + 1;
        }
      }

      _profile = UserProfile(
        topicFrequencies: topicFreqs,
        recentSearches: recent,
        lastActiveTime: DateTime.now(),
      );

      notifyListeners();
    } catch (e) {
      debugPrint('IntelligenceEngine error: $e');
    }
  }
}

final IntelligenceEngine intelligenceEngine = IntelligenceEngine();
