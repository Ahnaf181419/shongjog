import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Open-Meteo weather client.
///
/// Open-Meteo is free, no API key required, CC-BY licensed. We use it to
/// power the optional "আবহাওয়া" tile on the home screen — never as a
/// primary affordance, never as a lie (design.md §2: no fake-precise
/// numbers; numbers must come from real data or be absent).
///
/// Docs: https://open-meteo.com/en/docs
class WeatherService {
  /// 10s timeout — the home page already loads under a partial-error UX;
  /// we don't want weather fetches to delay the rest.
  static const _timeout = Duration(seconds: 10);

  /// Fetch current weather + 1-day forecast for [lat], [lon].
  /// Returns null on any network failure (silently — the home screen
  /// falls back to a neutral "tap to refresh" state).
  static Future<WeatherSnapshot?> fetch({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat'
      '&longitude=$lon'
      '&current=temperature_2m,relative_humidity_2m,precipitation,'
      'weather_code,wind_speed_10m'
      '&daily=temperature_2m_max,temperature_2m_min,'
      'precipitation_probability_max,weather_code'
      '&timezone=Asia/Dhaka'
      '&forecast_days=1',
    );
    try {
      final client = HttpClient();
      client.connectionTimeout = _timeout;
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(_timeout);
      if (res.statusCode != 200) return null;
      final body = await res
          .transform(utf8.decoder)
          .toList()
          .then((chunks) => chunks.join());
      final json = jsonDecode(body) as Map<String, dynamic>;
      return WeatherSnapshot.fromOpenMeteo(json);
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// A single weather observation + 1-day forecast, normalized for UI.
/// All values are real Open-Meteo numbers — no synthesis, no interpolation.
class WeatherSnapshot {
  final double tempC;
  final int humidityPct;
  final double precipitationMm;
  final int weatherCode;
  final double windKph;
  final double tempMaxC;
  final double tempMinC;
  final int precipProbabilityPct;

  const WeatherSnapshot({
    required this.tempC,
    required this.humidityPct,
    required this.precipitationMm,
    required this.weatherCode,
    required this.windKph,
    required this.tempMaxC,
    required this.tempMinC,
    required this.precipProbabilityPct,
  });

  factory WeatherSnapshot.fromOpenMeteo(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? const {};
    final daily = json['daily'] as Map<String, dynamic>? ?? const {};
    return WeatherSnapshot(
      tempC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      humidityPct: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      precipitationMm:
          (current['precipitation'] as num?)?.toDouble() ?? 0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      windKph: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      tempMaxC: ((daily['temperature_2m_max'] as List?)?.first as num?)
              ?.toDouble() ??
          0,
      tempMinC: ((daily['temperature_2m_min'] as List?)?.first as num?)
              ?.toDouble() ??
          0,
      precipProbabilityPct:
          ((daily['precipitation_probability_max'] as List?)?.first as num?)
                  ?.toInt() ??
              0,
    );
  }

  /// WMO weather code → Bangla label. Codes per Open-Meteo docs.
  /// https://open-meteo.com/en/docs (WMO Weather interpretation codes)
  String get conditionBn {
    switch (weatherCode) {
      case 0:
        return 'পরিষ্কার';
      case 1:
      case 2:
        return 'হালকা মেঘলা';
      case 3:
        return 'মেঘাচ্ছন্ন';
      case 45:
      case 48:
        return 'কুয়াশা';
      case 51:
      case 53:
      case 55:
        return 'গুঁড়ি গুঁড়ি বৃষ্টি';
      case 61:
      case 63:
        return 'বৃষ্টি';
      case 65:
        return 'ভারী বৃষ্টি';
      case 71:
      case 73:
      case 75:
        return 'তুষারপাত';
      case 80:
      case 81:
        return 'বৃষ্টির ঝাপটা';
      case 82:
        return 'ভারী বর্ষণ';
      case 95:
        return 'ঝড়ো হাওয়া';
      case 96:
      case 99:
        return 'বজ্রসহ ঝড়';
      default:
        return 'অজানা';
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
