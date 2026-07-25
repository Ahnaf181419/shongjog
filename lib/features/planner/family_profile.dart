import '../../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Home construction type. Determines flood/cyclone vulnerability —
/// tin-shed homes are high-risk, pucka (RCC) homes are safer.
enum HomeType {
  tinShed,
  pucka,
  apartment,
  unknown;

  /// Hardcoded Bangla label — kept for unit-test compatibility.
  /// Prefer [label] in UI code (uses AppLocalizations).
  String get labelBn => switch (this) {
        HomeType.tinShed => 'টিনের ঘর',
        HomeType.pucka => 'পাকা বাড়ি',
        HomeType.apartment => 'ফ্ল্যাট',
        HomeType.unknown => 'অজানা',
      };

  String label(AppLocalizations l10n) => switch (this) {
        HomeType.tinShed => l10n.familyHomeTypeTinShed,
        HomeType.pucka => l10n.familyHomeTypePucca,
        HomeType.apartment => l10n.familyHomeTypeFlat,
        HomeType.unknown => l10n.familyHomeTypeUnknown,
      };

  static HomeType fromString(String label) => switch (label) {
        'tinShed' => HomeType.tinShed,
        'pucka' => HomeType.pucka,
        'apartment' => HomeType.apartment,
        'টিনের ঘর' => HomeType.tinShed,
        'পাকা বাড়ি' => HomeType.pucka,
        'ফ্ল্যাট' => HomeType.apartment,
        _ => HomeType.unknown,
      };
}

/// Structured family profile for the AI planner / kit / risk modules.
///
/// Pure-Dart model persisted to SharedPreferences under `family_*`
/// keys — mirrors the existing `user_*` pattern from profile_screen.dart.
/// The AI prompt builders consume this struct to generate personalized
/// disaster plans, emergency kits, and risk assessments.
class FamilyProfile {
  final int familySize;
  final int childrenCount;
  final int elderlyCount;
  final bool hasPets;
  final HomeType homeType;
  final int? floorNumber;
  final List<String> medicalConditions;
  final bool nearbyRiver;
  final bool nearbyCoast;

  const FamilyProfile({
    this.familySize = 0,
    this.childrenCount = 0,
    this.elderlyCount = 0,
    this.hasPets = false,
    this.homeType = HomeType.unknown,
    this.floorNumber,
    this.medicalConditions = const [],
    this.nearbyRiver = false,
    this.nearbyCoast = false,
  });

  static const empty = FamilyProfile();

  bool get isEmpty => familySize == 0;

  Map<String, dynamic> toJson() => {
        'familySize': familySize,
        'childrenCount': childrenCount,
        'elderlyCount': elderlyCount,
        'hasPets': hasPets,
        'homeType': homeType.name,
        'floorNumber': floorNumber,
        'medicalConditions': medicalConditions,
        'nearbyRiver': nearbyRiver,
        'nearbyCoast': nearbyCoast,
      };

  factory FamilyProfile.fromJson(Map<String, dynamic> json) {
    return FamilyProfile(
      familySize: (json['familySize'] as num?)?.toInt() ?? 0,
      childrenCount: (json['childrenCount'] as num?)?.toInt() ?? 0,
      elderlyCount: (json['elderlyCount'] as num?)?.toInt() ?? 0,
      hasPets: json['hasPets'] as bool? ?? false,
      homeType: HomeType.values.firstWhere(
        (t) => t.name == json['homeType'],
        orElse: () => HomeType.unknown,
      ),
      floorNumber: (json['floorNumber'] as num?)?.toInt(),
      medicalConditions: ((json['medicalConditions'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      nearbyRiver: json['nearbyRiver'] as bool? ?? false,
      nearbyCoast: json['nearbyCoast'] as bool? ?? false,
    );
  }

  // ── SharedPreferences persistence ──────────────────────────────

  static const _kFamilySize = 'family_size';
  static const _kChildren = 'family_children';
  static const _kElderly = 'family_elderly';
  static const _kPets = 'family_pets';
  static const _kHomeType = 'family_home_type';
  static const _kFloor = 'family_floor';
  static const _kMedical = 'family_medical';
  static const _kRiver = 'family_river';
  static const _kCoast = 'family_coast';

  /// Save the profile. Passing [empty] clears all keys.
  static Future<void> save(FamilyProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    if (p.isEmpty) {
      await Future.wait([
        prefs.remove(_kFamilySize),
        prefs.remove(_kChildren),
        prefs.remove(_kElderly),
        prefs.remove(_kPets),
        prefs.remove(_kHomeType),
        prefs.remove(_kFloor),
        prefs.remove(_kMedical),
        prefs.remove(_kRiver),
        prefs.remove(_kCoast),
      ]);
      return;
    }
    await Future.wait([
      prefs.setInt(_kFamilySize, p.familySize),
      prefs.setInt(_kChildren, p.childrenCount),
      prefs.setInt(_kElderly, p.elderlyCount),
      prefs.setBool(_kPets, p.hasPets),
      prefs.setString(_kHomeType, p.homeType.name),
      if (p.floorNumber != null) prefs.setInt(_kFloor, p.floorNumber!),
      prefs.setStringList(_kMedical, p.medicalConditions),
      prefs.setBool(_kRiver, p.nearbyRiver),
      prefs.setBool(_kCoast, p.nearbyCoast),
    ]);
  }

  static Future<FamilyProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final homeTypeName = prefs.getString(_kHomeType);
    return FamilyProfile(
      familySize: prefs.getInt(_kFamilySize) ?? 0,
      childrenCount: prefs.getInt(_kChildren) ?? 0,
      elderlyCount: prefs.getInt(_kElderly) ?? 0,
      hasPets: prefs.getBool(_kPets) ?? false,
      homeType: homeTypeName == null
          ? HomeType.unknown
          : HomeType.values.firstWhere(
              (t) => t.name == homeTypeName,
              orElse: () => HomeType.unknown,
            ),
      floorNumber: prefs.getInt(_kFloor),
      medicalConditions: prefs.getStringList(_kMedical) ?? const [],
      nearbyRiver: prefs.getBool(_kRiver) ?? false,
      nearbyCoast: prefs.getBool(_kCoast) ?? false,
    );
  }
}
