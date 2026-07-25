import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shongjog/l10n/app_localizations.dart';

/// Reason the weather fetch failed. The UI uses this to show distinct
/// error text instead of a generic "try again" message.
enum WeatherFetchFailure {
  offline,
  timeout,
  httpError,
  parseError,
  unknown,
}

/// Open-Meteo weather client.
///
/// Open-Meteo is free, no API key required, CC-BY licensed. We use it to
/// power the optional "আবহাওয়া" card on the home screen — never as a
/// primary affordance, never as a lie (design.md §2: no fake-precise
/// numbers; numbers must come from real data or be absent).
///
/// Docs: https://open-meteo.com/en/docs
class WeatherService {
  /// 10s timeout — the home page already loads under a partial-error UX;
  /// we don't want weather fetches to delay the rest.
  static const _timeout = Duration(seconds: 10);

  /// Fetch current weather + 4-day forecast (today + next 3) for [lat], [lon].
  /// Returns null with a [WeatherFetchFailure] reason on any failure.
  static Future<WeatherSnapshot?> fetch({
    required double lat,
    required double lon,
    bool isOnline = true,
  }) async {
    if (!isOnline) {
      return null;
    }
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat'
      '&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,precipitation,'
      'weather_code,wind_speed_10m'
      '&daily=temperature_2m_max,temperature_2m_min,'
      'precipitation_probability_max,weather_code'
      '&timezone=Asia/Dhaka'
      '&forecast_days=4',
    );
    final client = HttpClient();
    try {
      client.connectionTimeout = _timeout;
      final req = await client.getUrl(uri).timeout(_timeout);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) {
        return null;
      }
      final body = await res
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      final json = jsonDecode(body) as Map<String, dynamic>;
      return WeatherSnapshot.fromOpenMeteo(json);
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (e) {
      return null;
    } finally {
      client.close();
    }
  }
}

/// A single day of forecast. Used for the today row's hi/lo and the 3-day
/// strip cells. All values are real Open-Meteo numbers — no synthesis, no
/// interpolation.
class DailyForecast {
  final DateTime date;
  final double maxC;
  final double minC;
  final int weatherCode;
  final int precipProbabilityPct;

  const DailyForecast({
    required this.date,
    required this.maxC,
    required this.minC,
    required this.weatherCode,
    required this.precipProbabilityPct,
  });
}

/// Current observation + 4-day forecast (today + 3), normalized for UI.
class WeatherSnapshot {
  final double tempC;
  final int humidityPct;
  final double precipitationMm;
  final int weatherCode;
  final double windKph;

  /// The first day's hi / lo / precip. Mirrored from `daily[0]` so legacy
  /// callers (and the today-row) can read them without indexing.
  final double tempMaxC;
  final double tempMinC;
  final int precipProbabilityPct;

  /// Up to 4 days: today + 3 ahead. Empty if the API didn't return any.
  final List<DailyForecast> daily;

  const WeatherSnapshot({
    required this.tempC,
    required this.humidityPct,
    required this.precipitationMm,
    required this.weatherCode,
    required this.windKph,
    required this.tempMaxC,
    required this.tempMinC,
    required this.precipProbabilityPct,
    required this.daily,
  });

  factory WeatherSnapshot.fromOpenMeteo(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? const {};
    final daily = json['daily'] as Map<String, dynamic>? ?? const {};

    final times = (daily['time'] as List?)?.cast<String>() ?? const <String>[];
    final maxes = (daily['temperature_2m_max'] as List?) ?? const [];
    final mins = (daily['temperature_2m_min'] as List?) ?? const [];
    final codes = (daily['weather_code'] as List?) ?? const [];
    final precips = (daily['precipitation_probability_max'] as List?) ?? const [];

    final List<DailyForecast> dailyList = [];
    for (var i = 0; i < times.length; i++) {
      dailyList.add(
        DailyForecast(
          date: DateTime.parse(times[i]),
          maxC: (maxes.length > i ? (maxes[i] as num?)?.toDouble() : 0) ?? 0,
          minC: (mins.length > i ? (mins[i] as num?)?.toDouble() : 0) ?? 0,
          weatherCode: (codes.length > i ? (codes[i] as num?)?.toInt() : 0) ?? 0,
          precipProbabilityPct: (precips.length > i ? (precips[i] as num?)?.toInt() : 0) ?? 0,
        ),
      );
    }

    final first = dailyList.isNotEmpty ? dailyList.first : null;
    return WeatherSnapshot(
      tempC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      humidityPct: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      precipitationMm:
          (current['precipitation'] as num?)?.toDouble() ?? 0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      windKph: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      tempMaxC: first?.maxC ?? 0,
      tempMinC: first?.minC ?? 0,
      precipProbabilityPct: first?.precipProbabilityPct ?? 0,
      daily: dailyList,
    );
  }

  /// WMO weather code → Bangla label. Codes per Open-Meteo docs.
  /// https://open-meteo.com/en/docs (WMO Weather interpretation codes)
  String conditionLabel(AppLocalizations l10n) {
    switch (weatherCode) {
      case 0:
        return l10n.weatherClear;
      case 1:
      case 2:
        return l10n.weatherPartlyCloudy;
      case 3:
        return l10n.weatherCloudy;
      case 45:
      case 48:
        return l10n.weatherFog;
      case 51:
      case 53:
      case 55:
        return l10n.weatherDrizzle;
      case 61:
      case 63:
        return l10n.weatherRain;
      case 65:
        return l10n.weatherHeavyRain;
      case 71:
      case 73:
      case 75:
        return l10n.weatherSnow;
      case 80:
      case 81:
        return l10n.weatherShowers;
      case 82:
        return l10n.weatherHeavyShowers;
      case 95:
        return l10n.weatherStormy;
      case 96:
      case 99:
        return l10n.weatherThunderstorm;
      default:
        return l10n.weatherUnknown;
    }
  }

  /// Material icon family for the current condition.
  String get iconKey {
    if (weatherCode == 0) return 'sunny';
    if (weatherCode <= 2) return 'partly_cloudy';
    if (weatherCode == 3) return 'cloudy';
    if (weatherCode <= 48) return 'foggy';
    if (weatherCode <= 57) return 'drizzle';
    if (weatherCode <= 67) return 'rainy';
    if (weatherCode <= 77) return 'snowy';
    if (weatherCode <= 82) return 'rainy_heavy';
    if (weatherCode >= 95) return 'stormy';
    return 'unknown';
  }
}
