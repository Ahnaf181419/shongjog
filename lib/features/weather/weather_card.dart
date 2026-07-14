import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/theme.dart';
import 'weather_service.dart';

/// Today's weather + next-3-day forecast card.
///
/// Per design.md §2: numbers must be real (from the corpus / device /
/// network) or absent. This widget fetches real data from Open-Meteo for
/// the device's GPS (or a Bangladesh default fallback). On any failure
/// it renders a neutral "tap to refresh" affordance — never a fake number.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard>
    with SingleTickerProviderStateMixin {
  WeatherSnapshot? _snapshot;
  bool _loading = true;
  String? _errorText;
  Position? _cachedPosition;
  // The card reserves a fixed height to keep layout stable across states
  // (loading / online / offline). Without this the screen jumps as the
  // card shrinks from "offline tap-to-load" to "full forecast" once data
  // arrives.
  static const double _cardHeight = 168;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    Position? pos = _cachedPosition;
    pos ??= await _tryPosition();
    _cachedPosition = pos;
    final lat = pos?.latitude ?? 23.81; // Dhaka fallback
    final lon = pos?.longitude ?? 90.41;
    final snap = await WeatherService.fetch(lat: lat, lon: lon);
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _loading = false;
      if (snap == null) {
        _errorText = pos == null
            ? 'অবস্থান নেই — ডিফল্ট ঢাকা দেখানো হচ্ছে'
            : 'আবহাওয়া লোড করা যায়নি';
      }
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
    return SizedBox(
      height: _cardHeight,
      child: Container(
        decoration: ShongjogTheme.weatherCard(context),
        clipBehavior: Clip.antiAlias,
        child: _buildInner(context),
      ),
    );
  }

  Widget _buildInner(BuildContext context) {
    if (_loading) return _buildSkeleton(context);
    if (_snapshot == null) return _buildOffline(context);
    return _buildLoaded(context, _snapshot!);
  }

  // ─── STATES ──────────────────────────────────────────────

  Widget _buildLoaded(BuildContext context, WeatherSnapshot s) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTodayRow(context, s),
        Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        _buildThreeDayStrip(context, s),
      ],
    );
  }

  Widget _buildTodayRow(BuildContext context, WeatherSnapshot s) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: ShongjogTheme.iconBadge(context),
            child: Icon(_iconFor(s.iconKey), color: cs.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'আবহাওয়া · আজ · ${s.conditionBn}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${s.tempC.round()}°',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        height: 1.05,
                        letterSpacing: -0.02,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '↑ ${s.tempMaxC.round()}°  ↓ ${s.tempMinC.round()}°',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.water_drop_rounded,
                  size: 14, color: cs.onSurfaceVariant),
              const SizedBox(height: 2),
              Text(
                '${s.precipProbabilityPct}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThreeDayStrip(BuildContext context, WeatherSnapshot s) {
    final cs = Theme.of(context).colorScheme;
    // Strip = days 1..3 (tomorrow + 2 more). Skip index 0 (today already
    // shown above). Open-Meteo returns up to 4 days; pad if fewer.
    final cells = <DailyForecast>[];
    for (var i = 1; i < s.daily.length && cells.length < 3; i++) {
      cells.add(s.daily[i]);
    }
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            Expanded(
              child: _DayCell(
                label: _dayLabel(cells[i].date, isToday: false),
                icon: _iconForCode(cells[i].weatherCode),
                maxC: cells[i].maxC,
                minC: cells[i].minC,
              ),
            ),
            if (i < cells.length - 1)
              Container(width: 1, color: cs.outlineVariant),
          ],
        ],
      ),
    );
  }

  Widget _buildOffline(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _load,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 22, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'কার্ড নেই — আবহাওয়া দেখতে চাপুন',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        height: 1.2,
                      ),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _errorText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.refresh_rounded,
                  size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Static placeholder — no spinner. Skeleton mirrors the loaded shape:
    // a gray today row, no strip. Same height prevents layout shift.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'আবহাওয়া — লোড হচ্ছে',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                _bar(cs.surfaceContainerHighest, width: 110, height: 22),
                const SizedBox(height: 6),
                _bar(cs.surfaceContainerHighest, width: 80, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(Color color, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────

  /// Bangla day label. 'আজ' / 'কাল' for the first two days (which the
  /// caller has already filtered to start at index 1 here), then short
  /// weekday names. Today (index 0 in the snapshot) is rendered in the
  /// big today row, not the strip.
  static String _dayLabel(DateTime d, {required bool isToday}) {
    // Indices 0..2 in the strip = tomorrow, +2, +3 relative to "today".
    // We can't know absolute "today" here without a clock, but the strip
    // indices map to weekday-1, weekday, weekday+1 in most cases.
    const names = [
      'সোম', // 1 Mon
      'মঙ্গল', // 2 Tue
      'বুধ', // 3 Wed
      'বৃহ', // 4 Thu
      'শুক্র', // 5 Fri
      'শনি', // 6 Sat
      'রবি', // 7 Sun
    ];
    return names[d.weekday - 1];
  }

  static IconData _iconForCode(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code <= 2) return Icons.cloud_queue_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code <= 48) return Icons.foggy;
    if (code <= 57) return Icons.grain_rounded;
    if (code <= 67) return Icons.umbrella_rounded;
    if (code <= 77) return Icons.ac_unit_rounded;
    if (code <= 82) return Icons.thunderstorm_rounded;
    if (code >= 95) return Icons.flash_on_rounded;
    return Icons.help_outline_rounded;
  }

  static IconData _iconFor(String key) {
    switch (key) {
      case 'sunny':
        return Icons.wb_sunny_rounded;
      case 'partly_cloudy':
        return Icons.cloud_queue_rounded;
      case 'cloudy':
        return Icons.cloud_rounded;
      case 'foggy':
        return Icons.foggy;
      case 'drizzle':
        return Icons.grain_rounded;
      case 'rainy':
        return Icons.umbrella_rounded;
      case 'rainy_heavy':
        return Icons.thunderstorm_rounded;
      case 'snowy':
        return Icons.ac_unit_rounded;
      case 'stormy':
        return Icons.flash_on_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

/// Compact day cell inside the 3-day strip. Renders day label,
/// icon, and max/min temperatures.
class _DayCell extends StatelessWidget {
  final String label;
  final IconData icon;
  final double maxC;
  final double minC;

  const _DayCell({
    required this.label,
    required this.icon,
    required this.maxC,
    required this.minC,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              height: 1.1,
            ),
          ),
          Icon(icon, color: cs.primary, size: 20),
          Text(
            '${maxC.round()}°  ${minC.round()}°',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
