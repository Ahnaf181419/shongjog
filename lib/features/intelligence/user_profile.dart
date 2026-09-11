class UserProfile {
  final Map<String, int> topicFrequencies;
  final List<String> recentSearches;
  final String? lastKnownArea;
  final DateTime? lastActiveTime;

  /// Locale of the recent searches — used to pick the right keyword set
  /// for the interest heuristics. Null means "assume bn" (legacy data).
  final String? localeCode;

  const UserProfile({
    required this.topicFrequencies,
    required this.recentSearches,
    this.lastKnownArea,
    this.lastActiveTime,
    this.localeCode,
  });

  /// Bangla keyword set — SSOT. Used in bn mode and as the fallback.
  static const _bnCyclone = ['ঘূর্ণিঝড়', 'আশ্রয়', 'সাইক্লোন', 'ঝড়'];
  static const _bnFlood = ['বন্যা', 'পানি', 'বৃষ্টি'];
  static const _bnMedical = ['ডায়রিয়া', 'সাপে', 'জ্বর', 'ওষুধ'];

  /// English keyword set — matched in addition to the bn set so an
  /// en-mode user searching "cyclone" or "flood" still triggers the
  /// matching insight.
  static const _enCyclone = [
    'cyclone', 'storm', 'hurricane', 'typhoon', 'shelter', 'evacuate', 'evacuation',
  ];
  static const _enFlood = [
    'flood', 'flooding', 'water', 'rain', 'monsoon', 'inundat',
  ];
  static const _enMedical = [
    'diarrhea', 'diarrhoea', 'snake', 'snakebite', 'fever', 'medicine', 'medical',
    'cholera', 'dehydration', 'ors',
  ];

  bool _any(List<String> needles) =>
      recentSearches.any((s) => needles.any(s.toLowerCase().contains));

  bool get showsCycloneInterest {
    if ((topicFrequencies['cyclone'] ?? 0) > 2 ||
        (topicFrequencies['shelter'] ?? 0) > 0) {
      return true;
    }
    if (_any(_bnCyclone)) return true;
    if (_any(_enCyclone)) return true;
    return false;
  }

  bool get showsFloodInterest {
    if ((topicFrequencies['flood'] ?? 0) > 2) return true;
    if (_any(_bnFlood)) return true;
    if (_any(_enFlood)) return true;
    return false;
  }

  bool get showsMedicalInterest {
    if ((topicFrequencies['medical'] ?? 0) > 2) return true;
    if (_any(_bnMedical)) return true;
    if (_any(_enMedical)) return true;
    return false;
  }

  factory UserProfile.empty() {
    return const UserProfile(
      topicFrequencies: {},
      recentSearches: [],
    );
  }
}
