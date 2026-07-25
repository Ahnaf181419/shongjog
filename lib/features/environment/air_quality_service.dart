import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../../l10n/app_localizations.dart';
import 'dart:io';

/// Open-Meteo Air Quality client — PM2.5 / PM10 / European AQI for a point.
///
/// Free, no API key, CC-BY 4.0. Same family as the existing WeatherService.
/// Docs: https://open-meteo.com/en/docs/air-quality-api
///
/// Bangladesh's air is frequently unhealthy (winter crop-burning + dust),
/// so an AQI chip on the home screen is genuinely actionable for users
/// with asthma or respiratory conditions. Degrades to null when offline.
class AirQualityService {
  static const _timeout = Duration(seconds: 10);

  /// Fetch current air quality for [lat], [lon].
  /// Returns null on offline / any failure.
  static Future<AirQualitySnapshot?> fetch({
    required double lat,
    required double lon,
    bool isOnline = true,
  }) async {
    if (!isOnline) return null;
    final uri = Uri.parse(
      'https://air-quality-api.open-meteo.com/v1/air-quality'
      '?latitude=$lat'
      '&longitude=$lon'
      '&current=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,european_aqi'
      '&timezone=auto',
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
      final current = json['current'] as Map<String, dynamic>?;
      if (current == null) return null;
      return AirQualitySnapshot.fromOpenMeteo(current);
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

/// Snapshot of current air-quality readings + a derived severity bucket.
class AirQualitySnapshot {
  final double pm25; // µg/m³
  final double pm10; // µg/m³
  final double? carbonMonoxide;
  final double? nitrogenDioxide;
  final double? sulphurDioxide;
  final double? ozone;
  final int? europeanAqi;

  const AirQualitySnapshot({
    required this.pm25,
    required this.pm10,
    this.carbonMonoxide,
    this.nitrogenDioxide,
    this.sulphurDioxide,
    this.ozone,
    this.europeanAqi,
  });

  factory AirQualitySnapshot.fromOpenMeteo(Map<String, dynamic> json) {
    return AirQualitySnapshot(
      pm25: (json['pm2_5'] as num?)?.toDouble() ?? 0,
      pm10: (json['pm10'] as num?)?.toDouble() ?? 0,
      carbonMonoxide: (json['carbon_monoxide'] as num?)?.toDouble(),
      nitrogenDioxide: (json['nitrogen_dioxide'] as num?)?.toDouble(),
      sulphurDioxide: (json['sulphur_dioxide'] as num?)?.toDouble(),
      ozone: (json['ozone'] as num?)?.toDouble(),
      europeanAqi: (json['european_aqi'] as num?)?.toInt(),
    );
  }

  /// PM2.5-based severity bucket (WHO 2021 air quality guidelines).
  /// WHO thresholds (24h mean, µg/m³):
  ///   <= 15   good
  ///   15–40   moderate
  ///   40–65   unhealthy for sensitive
  ///   65–150  unhealthy
  ///   > 150   very unhealthy
  AirQualitySeverity get severity {
    if (pm25 <= 15) return AirQualitySeverity.good;
    if (pm25 <= 40) return AirQualitySeverity.moderate;
    if (pm25 <= 65) return AirQualitySeverity.unhealthySensitive;
    if (pm25 <= 150) return AirQualitySeverity.unhealthy;
    return AirQualitySeverity.veryUnhealthy;
  }
}

enum AirQualitySeverity {
  good,
  moderate,
  unhealthySensitive,
  unhealthy,
  veryUnhealthy,
}

extension AirQualitySeverityL10n on AirQualitySeverity {
  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (this) {
      AirQualitySeverity.good => l10n.airGood,
      AirQualitySeverity.moderate => l10n.airModerate,
      AirQualitySeverity.unhealthySensitive => l10n.airUnhealthySensitive,
      AirQualitySeverity.unhealthy => l10n.airUnhealthy,
      AirQualitySeverity.veryUnhealthy => l10n.airVeryUnhealthy,
    };
  }
}

