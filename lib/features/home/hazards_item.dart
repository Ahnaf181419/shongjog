import 'package:flutter/material.dart';

import '../hazards/eonet_service.dart';
import '../hazards/gdacs_service.dart';
import '../hazards/usgs_earthquake_service.dart';

/// Normalised hazard item — the three feeds (EONET, USGS, GDACS) have
/// different shapes, so we project each into a common (icon, title,
/// subtitle, color, weight) triple for display.
class HazardsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final int weight;
  final Object? rawEvent;

  /// Whether this hazard is across a national border rather than inside
  /// Bangladesh. Such items are still worth showing when the hazard type
  /// crosses borders (cyclone, flood, earthquake), but they sort below every
  /// domestic hazard and the UI badges them — so a fire in Meghalaya can
  /// never read as a fire in Bangladesh.
  final bool isNearby;

  const HazardsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.weight,
    this.rawEvent,
    this.isNearby = false,
  });

  factory HazardsItem.fromEonet(EonetEvent e, BuildContext context) => HazardsItem(
        icon: _iconForEonet(e.category),
        title: e.category.label(context),
        subtitle: e.displayTitle,
        color: _colorForEonet(e.category),
        weight: 60 + (e.isActive ? 20 : 0) + _eonetBoost(e.category),
        rawEvent: e,
        isNearby: e.isCrossBorder,
      );

  factory HazardsItem.fromQuake(EarthquakeEvent q) => HazardsItem(
        icon: Icons.public_rounded,
        title: 'ভূমিকম্প M${q.magnitude.toStringAsFixed(1)}',
        subtitle: q.place,
        color: _colorForQuake(q.severity),
        weight: 80 + q.magnitude.toInt() * 5,
        rawEvent: q,
        isNearby: !q.isBangladesh,
      );

  factory HazardsItem.fromGdacs(GdacsAlert g, BuildContext context) {
    final w = switch (g.severity) {
      GdacsSeverity.red => 200,
      GdacsSeverity.orange => 110,
      GdacsSeverity.green => 30,
      GdacsSeverity.unknown => 50,
    };
    return HazardsItem(
      icon: Icons.campaign_rounded,
      title: g.title,
      subtitle: g.severity.label(context),
      color: _colorForGdacs(g.severity),
      weight: w,
      rawEvent: g,
      isNearby: !g.isBangladesh,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static IconData _iconForEonet(EonetCategory c) => switch (c) {
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

  static Color _colorForEonet(EonetCategory c) => switch (c) {
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

  static int _eonetBoost(EonetCategory c) => switch (c) {
        EonetCategory.severeStorms => 30,
        EonetCategory.floods => 25,
        EonetCategory.volcanoes => 20,
        EonetCategory.earthquakes => 15,
        _ => 0,
      };

  static Color _colorForQuake(EarthquakeSeverity s) => switch (s) {
        EarthquakeSeverity.strong => const Color(0xFFD32F2F),
        EarthquakeSeverity.moderate => const Color(0xFFE65100),
        EarthquakeSeverity.light => const Color(0xFFEF6C00),
      };

  static Color _colorForGdacs(GdacsSeverity s) => switch (s) {
        GdacsSeverity.red => const Color(0xFFD32F2F),
        GdacsSeverity.orange => const Color(0xFFE65100),
        GdacsSeverity.green => const Color(0xFF2E7D32),
        GdacsSeverity.unknown => const Color(0xFFEF6C00),
      };
}
