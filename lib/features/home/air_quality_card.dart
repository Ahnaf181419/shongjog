import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/theme.dart';
import '../../core/connectivity_provider.dart';
import '../environment/air_quality_service.dart';

/// Air-quality card for the home screen.
///
/// Shows the current PM2.5 reading and a WHO-based severity label
/// (ভালো / মাঝারি / ক্ষতিকর / অত্যন্ত ক্ষতিকর). Bangladesh's air is
/// frequently unhealthy in winter (crop-burning + dust + brick kilns),
/// so this is genuinely actionable for users with asthma or respiratory
/// conditions.
///
/// Behaviour matches WeatherCard:
/// - Offline → card not rendered.
/// - Online but fetch failed → tap-to-retry affordance.
/// - Online + fetched → severity-coloured chip + PM2.5 number.
class AirQualityCard extends StatefulWidget {
  const AirQualityCard({super.key});

  @override
  State<AirQualityCard> createState() => _AirQualityCardState();
}

class _AirQualityCardState extends State<AirQualityCard> {
  AirQualitySnapshot? _snapshot;
  bool _loading = true;
  bool _failed = false;
  bool _wasOnline = false;

  @override
  void initState() {
    super.initState();
    _wasOnline = connectivityProvider.isOnline;
    connectivityProvider.addListener(_onConnectivityChanged);
    _load();
  }

  @override
  void dispose() {
    connectivityProvider.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  /// Auto-refresh when the network comes back online. Avoids re-fetching
  /// on every transient flutter — only fires on a false → true flip.
  void _onConnectivityChanged() {
    final now = connectivityProvider.isOnline;
    if (now && !_wasOnline) {
      _load();
    }
    _wasOnline = now;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final isOnline = connectivityProvider.isOnline;
    final pos = await _tryPosition();
    final lat = pos?.latitude ?? 23.81; // Dhaka fallback
    final lon = pos?.longitude ?? 90.41;
    final snap = await AirQualityService.fetch(
      lat: lat,
      lon: lon,
      isOnline: isOnline,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _loading = false;
      _failed = snap == null;
    });
  }

  Future<Position?> _tryPosition() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consistent with LiveHazardsCard + WeatherCard: no card at all
    // when offline — the home screen shouldn't be full of tap-to-retry
    // affordances that can never succeed until the network returns.
    if (!connectivityProvider.isOnline) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.air_rounded,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'বায়ুর গুণমান',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                if (!_loading)
                  InkWell(
                    onTap: _load,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.refresh_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Text('তথ্য আনা হচ্ছে…',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ],
      );
    }
    if (_failed || _snapshot == null) {
      return InkWell(
        onTap: _load,
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'তথ্য আনা যায়নি। আবার চেষ্টা করুন।',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    return _buildLoaded(context, _snapshot!);
  }

  Widget _buildLoaded(BuildContext context, AirQualitySnapshot s) {
    final cs = Theme.of(context).colorScheme;
    final sevColor = _colorForSeverity(s.severity);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Severity chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: sevColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sevColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconForSeverity(s.severity), size: 14, color: sevColor),
              const SizedBox(width: 4),
              Text(
                s.severity.labelBn,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sevColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // PM2.5 number — the single most actionable reading
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PM2.5',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    s.pm25.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'µg/m³',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Secondary reading: PM10
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PM10',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              s.pm10.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Color _colorForSeverity(AirQualitySeverity s) => switch (s) {
        AirQualitySeverity.good => const Color(0xFF2E7D32), // green
        AirQualitySeverity.moderate => const Color(0xFFF9A825), // amber
        AirQualitySeverity.unhealthySensitive =>
          const Color(0xFFEF6C00), // deep orange
        AirQualitySeverity.unhealthy => const Color(0xFFD32F2F), // red
        AirQualitySeverity.veryUnhealthy =>
          const Color(0xFF7B1FA2), // purple
      };

  static IconData _iconForSeverity(AirQualitySeverity s) => switch (s) {
        AirQualitySeverity.good => Icons.sentiment_satisfied_rounded,
        AirQualitySeverity.moderate => Icons.sentiment_neutral_rounded,
        AirQualitySeverity.unhealthySensitive =>
          Icons.sentiment_dissatisfied_rounded,
        AirQualitySeverity.unhealthy => Icons.sentiment_very_dissatisfied_rounded,
        AirQualitySeverity.veryUnhealthy => Icons.dangerous_rounded,
      };
}

/// Re-export so callers don't need a separate import for the theme helper
/// if they want the same card shell. Kept here to avoid bloating theme.dart.
class AirQualityCardTheme {
  AirQualityCardTheme._();
  static BoxDecoration shell(BuildContext context) =>
      ShongjogTheme.weatherCard(context);
}
