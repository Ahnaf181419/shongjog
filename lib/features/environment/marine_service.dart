import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Open-Meteo Marine client — wave height + direction for the coast.
///
/// Free, no key, CC-BY 4.0. Returns wave height, wave direction, and
/// wind wave height for a point in the ocean.
/// Docs: https://open-meteo.com/en/docs/marine-weather-api
///
/// Cyclone-relevant for Bangladesh's southern coast (Cox's Bazar,
/// Chittagong, Bhola, Patuakhali, Sundarbans). Fishing communities
/// and coastal shelter managers use wave height to decide whether to
/// stay ashore. Degrades to null when offline.
class MarineService {
  static const _timeout = Duration(seconds: 10);

  /// Fetch a 3-day marine forecast for [lat], [lon] over the Bay of
  /// Bengal. Returns null on offline / any failure.
  static Future<MarineSnapshot?> fetch({
    required double lat,
    required double lon,
    bool isOnline = true,
  }) async {
    if (!isOnline) return null;
    final uri = Uri.parse(
      'https://marine-api.open-meteo.com/v1/marine'
      '?latitude=$lat'
      '&longitude=$lon'
      '&daily=wave_height_max,wave_direction_dominant,wind_wave_height_max'
      '&timezone=Asia/Dhaka'
      '&forecast_days=3',
    );
    final client = HttpClient();
    try {
      client.connectionTimeout = _timeout;
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = await res
          .transform(utf8.decoder)
          .toList()
          .then((chunks) => chunks.join());
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;
      return MarineSnapshot.fromOpenMeteo(daily);
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }
}

/// 3-day marine forecast, focused on wave height (the single most
/// actionable number for a coastal user deciding whether to fish or
/// evacuate).
class MarineSnapshot {
  final List<MarineDay> days;

  const MarineSnapshot({required this.days});

  factory MarineSnapshot.fromOpenMeteo(Map<String, dynamic> daily) {
    final times = (daily['time'] as List?)?.cast<String>() ?? const <String>[];
    final heights =
        (daily['wave_height_max'] as List?) ?? const [];
    final dirs =
        (daily['wave_direction_dominant'] as List?) ?? const [];
    final windHeights =
        (daily['wind_wave_height_max'] as List?) ?? const [];

    final List<MarineDay> out = [];
    for (var i = 0; i < times.length && i < 3; i++) {
      out.add(
        MarineDay(
          date: DateTime.tryParse(times[i]) ?? DateTime.now(),
          waveHeightMaxM:
              i < heights.length ? (heights[i] as num?)?.toDouble() ?? 0 : 0,
          waveDirectionDeg:
              i < dirs.length ? (dirs[i] as num?)?.toDouble() ?? 0 : 0,
          windWaveHeightMaxM: i < windHeights.length
              ? (windHeights[i] as num?)?.toDouble() ?? 0
              : 0,
        ),
      );
    }
    return MarineSnapshot(days: out);
  }

  /// Today's entry, if present.
  MarineDay? get today => days.isNotEmpty ? days.first : null;
}

/// A single day of the marine forecast.
class MarineDay {
  final DateTime date;
  final double waveHeightMaxM;
  final double waveDirectionDeg;
  final double windWaveHeightMaxM;

  const MarineDay({
    required this.date,
    required this.waveHeightMaxM,
    required this.waveDirectionDeg,
    required this.windWaveHeightMaxM,
  });

  /// Wave-severity bucket based on WMO / Beaufort-adjacent thresholds
  /// (wave height in metres). For coastal fishing + evacuation context:
  ///   < 1.2 m    calm
  ///   1.2–2.5 m  moderate
  ///   2.5–4.0 m  rough
  ///   > 4.0 m    very rough (cyclone territory)
  WaveSeverity get severity {
    if (waveHeightMaxM < 1.2) return WaveSeverity.calm;
    if (waveHeightMaxM <= 2.5) return WaveSeverity.moderate;
    if (waveHeightMaxM <= 4.0) return WaveSeverity.rough;
    return WaveSeverity.veryRough;
  }
}

enum WaveSeverity { calm, moderate, rough, veryRough }

extension WaveSeverityBn on WaveSeverity {
  String get labelBn => switch (this) {
        WaveSeverity.calm => 'শান্ত',
        WaveSeverity.moderate => 'মাঝারি',
        WaveSeverity.rough => 'অস্থির',
        WaveSeverity.veryRough => 'অত্যন্ত অস্থির',
      };
}
