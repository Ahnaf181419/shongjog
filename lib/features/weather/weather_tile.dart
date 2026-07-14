import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app/theme.dart';
import 'weather_service.dart';

/// Live weather tile for the home screen.
///
/// Per design.md §2: numbers must be real (from the corpus / device /
/// network) or absent. This widget fetches real data from Open-Meteo for
/// the device's GPS (or a Bangladesh default fallback). On any failure
/// it renders a neutral "tap to refresh" affordance — never a fake number.
class WeatherTile extends StatefulWidget {
  const WeatherTile({super.key});

  @override
  State<WeatherTile> createState() => _WeatherTileState();
}

class _WeatherTileState extends State<WeatherTile>
    with SingleTickerProviderStateMixin {
  WeatherSnapshot? _snapshot;
  bool _loading = true;
  String? _errorText;
  Position? _cachedPosition;

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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(ShongjogTheme.radius),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: _buildInner(context),
    );
  }

  Widget _buildInner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Row(
        children: [
          Icon(Icons.cloud_outlined, color: cs.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            'আবহাওয়া লোড হচ্ছে...',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
        ],
      );
    }
    if (_snapshot == null) {
      return InkWell(
        onTap: _load,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined,
                color: cs.onSurfaceVariant, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorText ?? 'আবহাওয়া আনতে চাপুন',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            Icon(Icons.refresh_rounded,
                color: cs.onSurfaceVariant, size: 18),
          ],
        ),
      );
    }
    final s = _snapshot!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _iconFor(s.iconKey),
            color: cs.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'আবহাওয়া — ${s.conditionBn}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${s.tempC.round()}°C  ·  বৃষ্টির সম্ভাবনা ${s.precipProbabilityPct}%',
                style: TextStyle(
                  fontSize: ShongjogTheme.bodyFloor,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: _load,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.refresh_rounded,
                size: 20, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  IconData _iconFor(String key) {
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
