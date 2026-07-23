import 'package:geolocator/geolocator.dart';

import '../admin/campaign_request.dart';
import 'notification_service.dart';

/// Handles proximity-based notifications for approved campaigns.
/// Checks if users are within a certain radius of approved campaigns
/// and generates appropriate notifications.
class ProximityNotificationService {
  static const double _defaultProximityRadiusKm = 5.0; // 5km radius

  /// Checks if the user's current position is near any approved campaigns.
  /// Returns a list of proximity insights for campaigns within the radius.
  static Future<List<ProactiveInsight>> checkProximity({
    required Position userPosition,
    required List<CampaignRequest> approvedCampaigns,
    double radiusKm = _defaultProximityRadiusKm,
  }) async {
    final insights = <ProactiveInsight>[];

    for (final campaign in approvedCampaigns) {
      final distance = _calculateDistance(
        userPosition.latitude,
        userPosition.longitude,
        campaign.latitude,
        campaign.longitude,
      );

      if (distance <= radiusKm) {
        insights.add(ProactiveInsight(
          title: 'নিকটস্থ ${campaign.type.labelBn}',
          message:
              '${campaign.type.labelBn} চলছে: ${campaign.address} (${distance.toStringAsFixed(1)} কিমি দূরত্বে)',
          route: '/shelter',
        ));
      }
    }

    return insights;
  }

  /// Calculates haversine distance between two points in kilometers.
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371.0; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = (dLat / 2).sin() * (dLat / 2).sin() +
        _toRadians(lat1).cos() *
            _toRadians(lat2).cos() *
            (dLon / 2).sin() *
            (dLon / 2).sin();
    final c = 2 * a.sqrt().asin();
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * 3.14159265359 / 180.0;
}

extension _DoubleExt on double {
  double sin() => (this * 3.14159265359 / 180.0).sin();
  double cos() => (this * 3.14159265359 / 180.0).cos();
  double sqrt() => this < 0 ? double.nan : this == 0 ? 0.0 : _sqrt(this);
  double asin() => this < -1 || this > 1 ? double.nan : _asin(this);

  static double _sqrt(double x) {
    if (x == 0) return 0.0;
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = 0.5 * (guess + x / guess);
    }
    return guess;
  }

  static double _asin(double x) {
    // Simple Taylor series approximation for asin
    double result = x;
    double term = x;
    double x2 = x * x;
    for (int n = 1; n < 10; n++) {
      term *= x2 * (2 * n - 1) / (2 * n);
      result += term / (2 * n + 1);
    }
    return result;
  }
}