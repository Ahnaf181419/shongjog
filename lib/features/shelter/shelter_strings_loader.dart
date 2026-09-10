import 'dart:convert';

import '../../core/text_loader.dart';

const _kAssetPath = 'assets/prompts/shelter.json';

class ShelterStrings {
  final String briefSystemRole;
  final String briefTask;
  final String briefShelterName;
  final String briefDistance;
  final String briefCapacity;
  final String briefLocation;
  final String briefUserLocation;
  final String briefActiveRisks;
  final String briefHazardEntry;
  final String briefAlerts;
  final String briefAlertEntry;
  final String briefAnswerLabel;
  final String briefFallbackLoading;
  final String briefFallbackDistance;
  final String briefFallbackCapacity;
  final String toolTitle;
  final String toolEntry;
  final String toolEntryWithCapacity;
  final String toolEmpty;
  final String toolMapHint;

  const ShelterStrings({
    required this.briefSystemRole,
    required this.briefTask,
    required this.briefShelterName,
    required this.briefDistance,
    required this.briefCapacity,
    required this.briefLocation,
    required this.briefUserLocation,
    required this.briefActiveRisks,
    required this.briefHazardEntry,
    required this.briefAlerts,
    required this.briefAlertEntry,
    required this.briefAnswerLabel,
    required this.briefFallbackLoading,
    required this.briefFallbackDistance,
    required this.briefFallbackCapacity,
    required this.toolTitle,
    required this.toolEntry,
    required this.toolEntryWithCapacity,
    required this.toolEmpty,
    required this.toolMapHint,
  });

  ShelterStrings._empty()
      : briefSystemRole = '',
        briefTask = '',
        briefShelterName = '',
        briefDistance = '',
        briefCapacity = '',
        briefLocation = '',
        briefUserLocation = '',
        briefActiveRisks = '',
        briefHazardEntry = '',
        briefAlerts = '',
        briefAlertEntry = '',
        briefAnswerLabel = '',
        briefFallbackLoading = '',
        briefFallbackDistance = '',
        briefFallbackCapacity = '',
        toolTitle = '',
        toolEntry = '',
        toolEntryWithCapacity = '',
        toolEmpty = '',
        toolMapHint = '';

  static ShelterStrings _fromMap(Map<String, dynamic> m) => ShelterStrings(
        briefSystemRole: m['brief_system_role'] as String,
        briefTask: m['brief_task'] as String,
        briefShelterName: m['brief_shelter_name'] as String,
        briefDistance: m['brief_distance'] as String,
        briefCapacity: m['brief_capacity'] as String,
        briefLocation: m['brief_location'] as String,
        briefUserLocation: m['brief_user_location'] as String,
        briefActiveRisks: m['brief_active_risks'] as String,
        briefHazardEntry: m['brief_hazard_entry'] as String,
        briefAlerts: m['brief_alerts'] as String,
        briefAlertEntry: m['brief_alert_entry'] as String,
        briefAnswerLabel: m['brief_answer_label'] as String,
        briefFallbackLoading: m['brief_fallback_loading'] as String,
        briefFallbackDistance: m['brief_fallback_distance'] as String,
        briefFallbackCapacity: m['brief_fallback_capacity'] as String,
        toolTitle: m['tool_title'] as String,
        toolEntry: m['tool_entry'] as String,
        toolEntryWithCapacity: m['tool_entry_with_capacity'] as String,
        toolEmpty: m['tool_empty'] as String,
        toolMapHint: m['tool_map_hint'] as String,
      );
}

ShelterStrings cachedShelter = ShelterStrings._empty();

Future<ShelterStrings> loadShelterStrings(String? locale) async {
  return TextLoader.loadJson<ShelterStrings>(_kAssetPath, (raw, localeCode) {
    final outer = jsonDecode(raw) as Map<String, dynamic>;
    final block = TextLoader.pickBundle(outer, localeCode);
    return ShelterStrings._fromMap(block);
  }, locale: locale);
}
