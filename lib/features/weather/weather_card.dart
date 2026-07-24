import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/theme.dart';
import '../../core/connectivity_provider.dart';
import '../../l10n/app_localizations.dart';
import 'weather_service.dart';

/// Today's weather + next-3-day forecast card.
///
/// Per design.md §2: numbers must be real (from the corpus / device /
/// network) or absent. This widget fetches real data from Open-Meteo for
/// the device's GPS (or a Bangladesh default fallback). On any failure
/// it renders a neutral "tap to refresh" affordance — never a fake number.
class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  /// Test-only: when true, the card skips GPS entirely — avoids the
  /// 7s pending-timer invariant failure in widget tests that run under
  /// FakeAsync. Must be set before the widget is pumped.
  static bool debugSkipGps = false;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  WeatherSnapshot? _snapshot;
  bool _loading = true;
  int? _errorKey;
  bool _usingFallback = false;
  // The card reserves a fixed height to keep layout stable across states
  // (loading / online / offline). Without this the screen jumps as the
  // card shrinks from "offline tap-to-load" to "full forecast" once data
  // arrives.
  static const double _cardHeight = 172;

  @override
  void initState() {
    super.initState();
    connectivityProvider.addListener(_onConnectivityChanged);
    // Defer the network + GPS fetch to the next frame so the first paint
    // completes before heavy I/O begins — avoids stacking with the
    // ShelterMap GPS request on cold start.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _onConnectivityChanged() {
    if (connectivityProvider.isOnline && _snapshot == null && !_loading) {
      _load();
    }
  }

  @override
  void dispose() {
    connectivityProvider.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorKey = null;
    });
    // Always try GPS — don't cache null so location can recover when the
    // user moves outdoors or grants permission after initially denying.
    final pos = await _tryPosition();
    final isFallback = pos == null;
    final lat = pos?.latitude ?? 23.81; // Dhaka fallback
    final lon = pos?.longitude ?? 90.41;
    final isOnline = connectivityProvider.isOnline;
    final snap = await WeatherService.fetch(
      lat: lat,
      lon: lon,
      isOnline: isOnline,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = snap;
      _loading = false;
      _usingFallback = isFallback;
      if (snap == null) {
        if (!isOnline) {
          _errorKey = 0;
        } else if (isFallback) {
          _errorKey = 1;
        } else {
          _errorKey = 2;
        }
      }
    });
  }

  Future<Position?> _tryPosition() async {
    if (WeatherCard.debugSkipGps) return null;
    try {
      return await _tryPositionInternal().timeout(const Duration(seconds: 7));
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _tryPositionInternal() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }
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
    } catch (e) {
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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _usingFallback ? _load : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: ShongjogTheme.iconBadge(context),
              child: _usingFallback
                  ? Icon(Icons.location_off_rounded, color: cs.onSurfaceVariant, size: 26)
                  : Icon(_iconFor(s.iconKey), color: cs.primary, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.weatherTodayLabel(s.conditionBn),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
                if (_usingFallback) ...[
                  const SizedBox(height: 1),
                  GestureDetector(
                    onTap: _load,
                    child: Text(
                      l10n.weatherFallbackLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
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
      height: 64,
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            Expanded(
              child: _DayCell(
                label: _dayLabel(cells[i].date),
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
    final l10n = AppLocalizations.of(context);
    final errorText = switch (_errorKey) {
      0 => l10n.weatherNoInternet,
      1 => l10n.weatherNoLocation,
      2 => l10n.weatherFetchError,
      _ => null,
    };
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
                      l10n.weatherTapToView,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        height: 1.2,
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        errorText,
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
                  AppLocalizations.of(context).weatherLoading,
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

  /// Bangla weekday label for the forecast strip cells.
  static String _dayLabel(DateTime d) {
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
