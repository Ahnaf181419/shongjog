import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/prompts/kit.json';

class KitStrings {
  final String systemRole;
  final String familyLine;
  final String children;
  final String elderly;
  final String pets;
  final String medical;
  final String medicalFollowup;
  final String waterZone;
  final String kitLabel;
  final String fallbackTitle;
  final String fallbackWater;
  final String fallbackFood;
  final String fallbackFlashlight;
  final String fallbackFirstAid;
  final String fallbackMedicine;
  final String fallbackDocuments;
  final String fallbackWhistle;
  final String fallbackBabyFood;
  final String fallbackDiapers;
  final String fallbackElderMedicine;
  final String fallbackPetFood;
  final String fallbackMedicalSpecial;
  final String fallbackLifeJacket;

  const KitStrings({
    required this.systemRole,
    required this.familyLine,
    required this.children,
    required this.elderly,
    required this.pets,
    required this.medical,
    required this.medicalFollowup,
    required this.waterZone,
    required this.kitLabel,
    required this.fallbackTitle,
    required this.fallbackWater,
    required this.fallbackFood,
    required this.fallbackFlashlight,
    required this.fallbackFirstAid,
    required this.fallbackMedicine,
    required this.fallbackDocuments,
    required this.fallbackWhistle,
    required this.fallbackBabyFood,
    required this.fallbackDiapers,
    required this.fallbackElderMedicine,
    required this.fallbackPetFood,
    required this.fallbackMedicalSpecial,
    required this.fallbackLifeJacket,
  });

  KitStrings._empty()
      : systemRole = '',
        familyLine = '',
        children = '',
        elderly = '',
        pets = '',
        medical = '',
        medicalFollowup = '',
        waterZone = '',
        kitLabel = '',
        fallbackTitle = '',
        fallbackWater = '',
        fallbackFood = '',
        fallbackFlashlight = '',
        fallbackFirstAid = '',
        fallbackMedicine = '',
        fallbackDocuments = '',
        fallbackWhistle = '',
        fallbackBabyFood = '',
        fallbackDiapers = '',
        fallbackElderMedicine = '',
        fallbackPetFood = '',
        fallbackMedicalSpecial = '',
        fallbackLifeJacket = '';

  static KitStrings _fromMap(Map<String, dynamic> m) => KitStrings(
        systemRole: m['systemRole'] as String,
        familyLine: m['familyLine'] as String,
        children: m['children'] as String,
        elderly: m['elderly'] as String,
        pets: m['pets'] as String,
        medical: m['medical'] as String,
        medicalFollowup: m['medicalFollowup'] as String,
        waterZone: m['waterZone'] as String,
        kitLabel: m['kitLabel'] as String,
        fallbackTitle: m['fallbackTitle'] as String,
        fallbackWater: m['fallbackWater'] as String,
        fallbackFood: m['fallbackFood'] as String,
        fallbackFlashlight: m['fallbackFlashlight'] as String,
        fallbackFirstAid: m['fallbackFirstAid'] as String,
        fallbackMedicine: m['fallbackMedicine'] as String,
        fallbackDocuments: m['fallbackDocuments'] as String,
        fallbackWhistle: m['fallbackWhistle'] as String,
        fallbackBabyFood: m['fallbackBabyFood'] as String,
        fallbackDiapers: m['fallbackDiapers'] as String,
        fallbackElderMedicine: m['fallbackElderMedicine'] as String,
        fallbackPetFood: m['fallbackPetFood'] as String,
        fallbackMedicalSpecial: m['fallbackMedicalSpecial'] as String,
        fallbackLifeJacket: m['fallbackLifeJacket'] as String,
      );
}

KitStrings cachedKit = KitStrings._empty();

Future<KitStrings> loadKitStrings(String? locale) async {
  return TextLoader.loadJson<KitStrings>(_kAssetPath, (raw, localeCode) {
    final outer = jsonDecode(raw) as Map<String, dynamic>;
    final block = TextLoader.pickBundle(outer, locale);
    return KitStrings._fromMap(block);
  });
}

Future<void> primeKitCache(String? locale) async {
  cachedKit = await loadKitStrings(locale);
}
