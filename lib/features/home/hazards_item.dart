import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../hazards/eonet_service.dart';
import '../hazards/gdacs_service.dart';
import '../hazards/usgs_earthquake_service.dart';
import '../../core/bangla_numerals.dart';

/// Normalised hazard item — the three feeds (EONET, USGS, GDACS) have
/// different shapes, so we project each into a common (icon, color,
/// weight, isNearby) shape plus a variant that the row resolves against
/// the live `AppLocalizations` in `build()`. Locale-dependent text
/// (category label, severity, etc.) is no longer baked into the item.
class HazardsItem {
  final IconData icon;
  final Color color;
  final int weight;
  final Object? rawEvent;
  final HazardsVariant variant;

  /// Whether this hazard is across a national border rather than inside
  /// Bangladesh. Such items are still worth showing when the hazard type
  /// crosses borders (cyclone, flood, earthquake), but they sort below every
  /// domestic hazard and the UI badges them — so a fire in Meghalaya can
  /// never read as a fire in Bangladesh.
  final bool isNearby;

  const HazardsItem({
    required this.icon,
    required this.color,
    required this.weight,
    required this.variant,
    this.rawEvent,
    this.isNearby = false,
  });

  factory HazardsItem.fromEonet(EonetEvent e) => HazardsItem(
        icon: _iconForEonet(e.category),
        color: _colorForEonet(e.category),
        weight: 60 + (e.isActive ? 20 : 0) + _eonetBoost(e.category),
        variant: HazardsVariant.eonet(
          category: e.category,
          displayTitle: e.displayTitle,
        ),
        rawEvent: e,
        isNearby: e.isCrossBorder,
      );

  factory HazardsItem.fromQuake(EarthquakeEvent q) => HazardsItem(
        icon: Icons.public_rounded,
        color: _colorForQuake(q.severity),
        weight: 80 + q.magnitude.toInt() * 5,
        variant: HazardsVariant.quake(
          magnitude: q.magnitude,
          place: q.place,
        ),
        rawEvent: q,
        isNearby: !q.isBangladesh,
      );

  factory HazardsItem.fromGdacs(GdacsAlert g) {
    final w = switch (g.severity) {
      GdacsSeverity.red => 200,
      GdacsSeverity.orange => 110,
      GdacsSeverity.green => 30,
      GdacsSeverity.unknown => 50,
    };
    return HazardsItem(
      icon: Icons.campaign_rounded,
      color: _colorForGdacs(g.severity),
      weight: w,
      variant: HazardsVariant.gdacs(
        title: g.title,
        severity: g.severity,
      ),
      rawEvent: g,
      isNearby: !g.isBangladesh,
    );
  }

  /// Resolves the locale-dependent title against the active l10n bundle.
  String titleFor(AppLocalizations l10n) => switch (variant) {
        HazardsEonet(:final category, :final displayTitle) =>
          '${category.labelL10n(l10n)} · $displayTitle',
        HazardsQuake(:final magnitude) =>
          l10n.hazardEarthquakeMag(digitsForLocale(magnitude.toStringAsFixed(1), l10n.localeName)),
        HazardsGdacs(:final title) => title,
      };

  /// Resolves the locale-dependent subtitle against the active l10n bundle.
  String subtitleFor(AppLocalizations l10n) => switch (variant) {
        HazardsEonet() => '',
        HazardsQuake(:final place) => place,
        HazardsGdacs(:final severity) => severity.labelL10n(l10n),
      };
}

/// Sealed variants so each item can carry exactly the locale-independent
/// data needed to resolve its text against any `AppLocalizations`.
sealed class HazardsVariant {
  const HazardsVariant();

  factory HazardsVariant.eonet({
    required EonetCategory category,
    required String displayTitle,
  }) =>
      HazardsEonet(category: category, displayTitle: displayTitle);

  factory HazardsVariant.quake({
    required double magnitude,
    required String place,
  }) =>
      HazardsQuake(magnitude: magnitude, place: place);

  factory HazardsVariant.gdacs({
    required String title,
    required GdacsSeverity severity,
  }) =>
      HazardsGdacs(title: title, severity: severity);
}

class HazardsEonet extends HazardsVariant {
  final EonetCategory category;
  final String displayTitle;
  const HazardsEonet({required this.category, required this.displayTitle});
}

class HazardsQuake extends HazardsVariant {
  final double magnitude;
  final String place;
  const HazardsQuake({required this.magnitude, required this.place});
}

class HazardsGdacs extends HazardsVariant {
  final String title;
  final GdacsSeverity severity;
  const HazardsGdacs({required this.title, required this.severity});
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

IconData _iconForEonet(EonetCategory c) => switch (c) {
      EonetCategory.severeStorms => Icons.thunderstorm_rounded,
      EonetCategory.floods => Icons.water_rounded,
      EonetCategory.earthquakes => Icons.public_rounded,
      EonetCategory.wildfires => Icons.local_fire_department_rounded,
      EonetCategory.volcanoes => Icons.whatshot_rounded,
      EonetCategory.landslides => Icons.landscape_rounded,
      EonetCategory.extremeTemperatures => Icons.thermostat_rounded,
      EonetCategory.drought => Icons.grain_rounded,
      EonetCategory.seaLakeIce => Icons.ac_unit_rounded,
      EonetCategory.manmade || EonetCategory.other =>
        Icons.crisis_alert_rounded,
    };

Color _colorForEonet(EonetCategory c) => switch (c) {
      EonetCategory.severeStorms ||
      EonetCategory.floods ||
      EonetCategory.volcanoes ||
      EonetCategory.landslides =>
        const Color(0xFFD32F2F),
      EonetCategory.earthquakes ||
      EonetCategory.wildfires =>
        const Color(0xFFE65100),
      _ => const Color(0xFFEF6C00),
    };

int _eonetBoost(EonetCategory c) => switch (c) {
      EonetCategory.severeStorms => 30,
      EonetCategory.floods => 25,
      EonetCategory.volcanoes => 20,
      EonetCategory.earthquakes => 15,
      _ => 0,
    };

Color _colorForQuake(EarthquakeSeverity s) => switch (s) {
      EarthquakeSeverity.strong => const Color(0xFFD32F2F),
      EarthquakeSeverity.moderate => const Color(0xFFE65100),
      EarthquakeSeverity.light => const Color(0xFFEF6C00),
    };

Color _colorForGdacs(GdacsSeverity s) => switch (s) {
      GdacsSeverity.red => const Color(0xFFD32F2F),
      GdacsSeverity.orange => const Color(0xFFE65100),
      GdacsSeverity.green => const Color(0xFF2E7D32),
      GdacsSeverity.unknown => const Color(0xFFEF6C00),
    };
