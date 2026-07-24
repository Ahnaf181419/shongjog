import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/connectivity_provider.dart';
import '../environment/marine_service.dart';

/// Marine wave-forecast card — coast-aware.
///
/// Shows the 3-day wave-height forecast for the nearest Bay of Bengal
/// reference point. Only renders when the user's GPS is within ~150 km
/// of the southern coast — cyclone-relevant for fishing communities
/// and coastal shelter managers in Cox's Bazar, Chittagong, Bhola,
/// Patuakhali, and the Sundarbans. Inland users (Dhaka, Sylhet,
/// Rajshahi) never see this card, so it adds zero noise to their home
/// screen.
///
/// Behaviour matches AirQualityCard + LiveHazardsCard:
/// - Offline → not rendered.
/// - Online but inland → not rendered.
/// - Online + coastal + fetch failed → tap-to-retry.
/// - Online + coastal + fetched → today's wave height + severity chip
///   + a compact 3-day strip.
class MarineCard extends StatefulWidget {
  const MarineCard({super.key});

  @override
  State<MarineCard> createState() => _MarineCardState();
}

class _MarineCardState extends State<MarineCard> {
  MarineSnapshot? _snapshot;
  bool _loading = true;
  bool _failed = false;
  bool _coastal = false;
  _CoastalPoint? _reference;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final isOnline = connectivityProvider.isOnline;
    final pos = await _tryPosition();
    final ref = pos != null ? _nearestCoastalPoint(pos) : null;
    final coastal = ref != null && ref.distanceKm <= 150;
    if (!mounted) return;
    setState(() {
      _coastal = coastal;
      _reference = coastal ? ref : null;
    });

    if (!isOnline || !coastal) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final snap = await MarineService.fetch(
      lat: ref.lat,
      lon: ref.lon,
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
    // Offline → not rendered.
    if (!connectivityProvider.isOnline) return const SizedBox.shrink();
    // Loading — reserve nothing; the card may not end up rendered at all
    // (inland users). A zero-size placeholder avoids layout shift on
    // inland devices while coastal devices reveal the card on completion.
    if (_loading && !_coastal) return const SizedBox.shrink();
    // Inland — no card.
    if (!_coastal) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
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
                Icon(Icons.waves_rounded,
                    size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'সমুদ্রের উত্তালতা',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (_reference != null)
                  Text(
                    _reference!.labelBn,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                if (!_loading) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _load,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.refresh_rounded,
                          size: 16, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
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
    if (_failed || _snapshot == null || _snapshot!.days.isEmpty) {
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
    final today = _snapshot!.today;
    if (today == null) {
      // No today entry — fall back to the tap-to-retry affordance.
      return InkWell(
        onTap: _load,
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'তথ্য আনা যায়নি। আবার চেষ্টা করুন।',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }
    final sevColor = _colorForSeverity(today.severity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
                  Icon(_iconForSeverity(today.severity),
                      size: 14, color: sevColor),
                  const SizedBox(width: 4),
                  Text(
                    today.severity.labelBn,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('সর্বোচ্চ তরঙ্গ',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        today.waveHeightMaxM.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('মিটার',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_snapshot!.days.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 1; i < _snapshot!.days.length && i < 3; i++) ...[
                Expanded(
                  child: _MarineDayCell(day: _snapshot!.days[i]),
                ),
                if (i < 2 && i < _snapshot!.days.length - 1)
                  Container(width: 1, height: 36, color: cs.outlineVariant),
              ],
            ],
          ),
        ],
      ],
    );
  }

  static Color _colorForSeverity(WaveSeverity s) => switch (s) {
        WaveSeverity.calm => const Color(0xFF2E7D32),
        WaveSeverity.moderate => const Color(0xFFF9A825),
        WaveSeverity.rough => const Color(0xFFEF6C00),
        WaveSeverity.veryRough => const Color(0xFFD32F2F),
      };

  static IconData _iconForSeverity(WaveSeverity s) => switch (s) {
        WaveSeverity.calm => Icons.water_outlined,
        WaveSeverity.moderate => Icons.waves_outlined,
        WaveSeverity.rough => Icons.waves_rounded,
        WaveSeverity.veryRough => Icons.tsunami_rounded,
      };
}

/// Compact day cell for the 2-day forecast strip (tomorrow + day after).
class _MarineDayCell extends StatelessWidget {
  const _MarineDayCell({required this.day});
  final MarineDay day;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _label(day.date),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${day.waveHeightMaxM.toStringAsFixed(1)} মি',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _label(DateTime d) {
    const names = [
      'সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র', 'শনি', 'রবি',
    ];
    return names[d.weekday - 1];
  }
}

/// A reference coastal point with its Bangla label.
class _CoastalPoint {
  final double lat;
  final double lon;
  final String labelBn;
  final double distanceKm;
  const _CoastalPoint(this.lat, this.lon, this.labelBn, this.distanceKm);
}

/// Bangladesh's southern coastal reference points — the marine API is
/// queried for whichever is nearest to the user. Using fixed reference
/// points avoids the "user is inland, marine API returns nonsense for
/// their lat/lon" problem, and matches how coastal radio broadcasts
/// report sea state for named stretches of coast.
const _coastalPoints = <_CoastalPointDef>[
  _CoastalPointDef(20.45, 92.34, 'কক্সবাজার'),
  _CoastalPointDef(22.33, 91.82, 'চট্টগ্রাম'),
  _CoastalPointDef(22.17, 90.76, 'ভোলা'),
  _CoastalPointDef(22.35, 90.43, 'পটুয়াখালী'),
  _CoastalPointDef(21.95, 89.08, 'সুন্দরবন'),
  _CoastalPointDef(21.65, 91.97, 'টেকনাফ'),
];

class _CoastalPointDef {
  final double lat;
  final double lon;
  final String labelBn;
  const _CoastalPointDef(this.lat, this.lon, this.labelBn);
}

/// Return the nearest coastal reference point + its haversine distance
/// from [pos], or null if no GPS position is available.
_CoastalPoint? _nearestCoastalPoint(Position pos) {
  _CoastalPointDef? nearestDef;
  var nearestKm = double.infinity;
  for (final p in _coastalPoints) {
    final km = _haversineKm(pos.latitude, pos.longitude, p.lat, p.lon);
    if (km < nearestKm) {
      nearestKm = km;
      nearestDef = p;
    }
  }
  if (nearestDef == null) return null;
  return _CoastalPoint(
    nearestDef.lat,
    nearestDef.lon,
    nearestDef.labelBn,
    nearestKm,
  );
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _toRad(double deg) => deg * math.pi / 180;
