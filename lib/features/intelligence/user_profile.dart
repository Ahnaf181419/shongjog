class UserProfile {
  final Map<String, int> topicFrequencies;
  final List<String> recentSearches;
  final String? lastKnownArea;
  final DateTime? lastActiveTime;

  const UserProfile({
    required this.topicFrequencies,
    required this.recentSearches,
    this.lastKnownArea,
    this.lastActiveTime,
  });

  bool get showsCycloneInterest {
    return (topicFrequencies['cyclone'] ?? 0) > 2 ||
           (topicFrequencies['shelter'] ?? 0) > 0 ||
           recentSearches.any((s) => s.contains('ঘূর্ণিঝড়') || s.contains('আশ্রয়'));
  }

  bool get showsFloodInterest {
    return (topicFrequencies['flood'] ?? 0) > 2 ||
           recentSearches.any((s) => s.contains('বন্যা') || s.contains('পানি'));
  }

  bool get showsMedicalInterest {
    return (topicFrequencies['medical'] ?? 0) > 2 ||
           recentSearches.any((s) => s.contains('ডায়রিয়া') || s.contains('সাপে') || s.contains('জ্বর'));
  }

  factory UserProfile.empty() {
    return const UserProfile(
      topicFrequencies: {},
      recentSearches: [],
    );
  }
}
