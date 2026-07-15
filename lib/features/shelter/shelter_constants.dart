/// Shared constants for the shelter feature. Lifted from
/// `shelter_map_screen.dart` and the extracted widgets so the values
/// are greppable, tunable in one place, and surface as named symbols
/// in widget tests.
class ShelterConstants {
  ShelterConstants._();

  // ─── User-location dot ────────────────────────────────────────────
  static const Duration pulseDuration = Duration(milliseconds: 1400);
  static const double pulseMinAlpha = 0.18;
  static const double pulseMaxAlpha = 0.36;
  static const double userDotOuter = 56;
  static const double userDotInner = 18;

  // ─── Shelter marker ───────────────────────────────────────────────
  static const double markerSmall = 44;
  static const double markerLarge = 60;
  static const double shelterIconSmall = 24;
  static const double shelterIconLarge = 32;

  // ─── Route polyline ───────────────────────────────────────────────
  static const double routeStrokeWidth = 5;
  static const double mapFitPadding = 60;

  // ─── Map initial zoom ────────────────────────────────────────────
  static const double zoomWithUser = 11;
  static const double zoomWithoutUser = 8;

  // ─── Network / GPS timeouts (matched by `OsrmRouteService`) ─────
  static const Duration gpsTimeout = Duration(seconds: 10);

  // ─── Banner alpha (offline pill in AppBar.bottom) ───────────────
  static const double bannerBgAlpha = 0.06;
  static const double bannerFgAlpha = 0.7;
}
