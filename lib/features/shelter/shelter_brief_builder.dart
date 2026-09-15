import 'nearest_shelter.dart';
import 'shelter_strings_loader.dart';
import '../hazards/eonet_service.dart';
import '../hazards/gdacs_service.dart';
import '../../l10n/app_localizations.dart';

/// Builds the prompt for an AI-generated per-shelter risk brief
/// (Option 3 in docs/AI-MAP-FEATURES.md).
///
/// When the user taps a shelter pin, this produces a one-sentence
/// Bangla risk assessment that combines distance, capacity, and
/// proximity to live hazards. The model writes the sentence; this
/// class supplies the structured context.
///
/// Also provides a deterministic fallback string for when the model
/// is offline or fails — the info card always shows something useful.
class ShelterBriefBuilder {
  ShelterBriefBuilder._();

  /// Build the prompt for the model. Returns null when there's not
  /// enough context to write a meaningful brief (no user position or
  /// no shelter).
  static String? buildPrompt({
    required double? userLat,
    required double? userLon,
    required RankedShelter? shelter,
    List<EonetEvent>? hazards,
    List<GdacsAlert>? alerts,
    ShelterStrings? s,
  }) {
    final strings = s ?? cachedShelter;
    if (userLat == null || userLon == null || shelter == null) return null;

    final shelterData = shelter.shelter;
    final name = shelterData.nameBn.isNotEmpty ? shelterData.nameBn : shelterData.name;
    final buf = StringBuffer();
    buf.writeln(strings.briefSystemRole);
    buf.writeln(strings.briefTask);
    buf.writeln();
    buf.writeln(strings.briefShelterName.replaceAll('{name}', name));
    buf.writeln(strings.briefDistance.replaceAll('{km}', shelter.km.toStringAsFixed(1)));
    if (shelterData.capacity != null) {
      buf.writeln(strings.briefCapacity.replaceAll('{capacity}', '${shelterData.capacity}'));
    }
    buf.writeln(strings.briefLocation
        .replaceAll('{lat}', '${shelterData.lat}')
        .replaceAll('{lon}', '${shelterData.lon}'));
    buf.writeln(strings.briefUserLocation
        .replaceAll('{lat}', '$userLat')
        .replaceAll('{lon}', '$userLon'));

    if (hazards != null && hazards.isNotEmpty) {
      buf.writeln(strings.briefActiveRisks);
      for (final h in hazards.take(3)) {
        buf.writeln(strings.briefHazardEntry
            .replaceAll('{category}', h.category.labelBn)
            .replaceAll('{title}', h.title)
            .replaceAll('{lat}', '${h.latitude}')
            .replaceAll('{lon}', '${h.longitude}'));
      }
    }
    if (alerts != null && alerts.isNotEmpty) {
      buf.writeln(strings.briefAlerts);
      for (final a in alerts.take(2)) {
        buf.writeln(strings.briefAlertEntry
            .replaceAll('{severity}', a.severity.labelBn)
            .replaceAll('{title}', a.title));
      }
    }

    buf.writeln();
    buf.write(strings.briefAnswerLabel);
    return buf.toString();
  }

  /// Deterministic fallback brief for when the model is unavailable.
  /// Always returns a useful sentence — never empty.
  ///
  /// Locale-aware (2026-09-09): English mode used to show the Bangla
  /// sentence while the model loaded (or when the model is off). The
  /// no-l10n overload stays for the AI-prompt path and old callers.
  static String fallbackBrief({
    required RankedShelter? shelter,
    AppLocalizations? l10n,
    ShelterStrings? s,
  }) {
    final strings = s ?? cachedShelter;
    if (shelter == null) {
      return l10n?.shelterBriefLoading ?? strings.briefFallbackLoading;
    }
    final shelterData = shelter.shelter;
    final isBn = l10n == null || l10n.localeName.startsWith('bn');
    final name = isBn
        ? (shelterData.nameBn.isNotEmpty ? shelterData.nameBn : shelterData.name)
        : (shelterData.name.isNotEmpty ? shelterData.name : shelterData.nameBn);
    if (l10n != null && !isBn) {
      // English deterministic brief.
      final brief = l10n.shelterBriefDistance(name, shelter.km.toStringAsFixed(1));
      if (shelterData.capacity != null) {
        return brief + l10n.shelterBriefCapacity('${shelterData.capacity}');
      }
      return brief;
    }
    // Bangla brief (original behavior) — Bengali numerals.
    final distBn = _toBangla(shelter.km.toStringAsFixed(1));
    var brief = strings.briefFallbackDistance
        .replaceAll('{name}', name)
        .replaceAll('{km}', distBn);
    if (shelterData.capacity != null) {
      final capBn = _toBangla('${shelterData.capacity}');
      brief += strings.briefFallbackCapacity.replaceAll('{capacity}', capBn);
    }
    return brief;
  }

  static String _toBangla(String s) {
    const map = {
      '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
      '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
    };
    return s.split('').map((c) => map[c] ?? c).join();
  }
}
