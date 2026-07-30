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

  // ─── Fallback centre (Dhaka) ─────────────────────────────────────
  // Used to rank + centre the map when no GPS fix is available, so the
  // shelter list and search panel remain usable without location.
  static const double fallbackLat = 23.8;
  static const double fallbackLon = 90.4;

  // ─── Network / GPS timeouts (matched by `OsrmRouteService`) ─────
  // First attempt uses `LocationAccuracy.high` with [gpsTimeout] (15s).
  // On timeout we retry with `LocationAccuracy.medium` and the shorter
  // [gpsFallbackTimeout] — a degraded fix is strictly better than none
  // on a cold-start GPS (indoors, first boot, emulator). The old 10s
  // floor was too aggressive and surfaced as a generic "GPS not found".
  static const Duration gpsTimeout = Duration(seconds: 15);
  static const Duration gpsFallbackTimeout = Duration(seconds: 8);

  // ─── Banner alpha (offline pill in AppBar.bottom) ───────────────
  static const double bannerBgAlpha = 0.06;
  static const double bannerFgAlpha = 0.7;
}
