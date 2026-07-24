import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// NASA EONET client — live natural hazards near Bangladesh.
///
/// EONET (Earth Observatory Natural Event Tracker) is a NASA open API
/// that publishes natural events (storms, floods, wildfires, earthquakes,
/// volcanoes, landslides, extreme temperatures, drought) with geo-
/// coordinates and date ranges. Free, no API key.
///
/// Docs: https://eonet.gsfc.nasa.gov/
///
/// Used by the home-screen "live hazards" card to surface cyclones,
/// floods, and earthquakes currently in or near Bangladesh. Degrades to
/// null (card not shown) when offline — consistent with the app's
/// offline-first thesis.
class EonetService {
  static const _timeout = Duration(seconds: 10);

  /// Bounding box for Bangladesh + the Bay of Bengal cyclone basin.
  /// [west, north, east, south] — the format EONET expects.
  static const List<double> bangladeshBbox = [88.0, 27.5, 93.5, 20.0];

  /// Fetch open (currently-active) hazards within [bbox]. Returns an empty
  /// list if online but nothing is active; returns null on any failure or
  /// when offline. An empty list is a meaningful result (no active hazards);
  /// null means "we don't know".
  static Future<List<EonetEvent>?> fetchOpenHazards({
    List<double>? bbox,
    bool isOnline = true,
  }) async {
    if (!isOnline) return null;
    final box = bbox ?? bangladeshBbox;
    // EONET bbox is west,north,east,south.
    final bboxParam = '${box[0]},${box[1]},${box[2]},${box[3]}';
    final uri = Uri.parse(
      'https://eonet.gsfc.nasa.gov/api/v3/events'
      '?status=open'
      '&bbox=$bboxParam'
      '&limit=20',
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
      final events = json['events'];
      if (events is! List) return null;
      return events
          .map((e) => EonetEvent.tryParse(e as Map<String, dynamic>))
          .whereType<EonetEvent>()
          .toList();
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

/// A single EONET hazard event with at least one geo-point.
class EonetEvent {
  final String id;
  final String title;
  final EonetCategory category;
  final DateTime? opened;
  final DateTime? closed;
  final double latitude;
  final double longitude;

  const EonetEvent({
    required this.id,
    required this.title,
    required this.category,
    this.opened,
    this.closed,
    required this.latitude,
    required this.longitude,
  });

  /// Parse a raw EONET event. Returns null if the event has no usable
  /// geometry (EONET occasionally emits events with only date ranges).
  static EonetEvent? tryParse(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final title = json['title'] as String?;
    if (id == null || title == null) return null;

    // Category: events carry a list of category objects, each with id/title.
    final cats = json['categories'];
    String? catId;
    String? catTitle;
    if (cats is List && cats.isNotEmpty) {
      final first = cats.first;
      if (first is Map<String, dynamic>) {
        catId = first['id'] as String?;
        catTitle = first['title'] as String?;
      }
    }
    final category = EonetCategory.fromApi(catId, catTitle);

    // Geometry: a list of {date, type: 'Point', coordinates: [lon, lat]}.
    // Take the most recent.
    final geom = json['geometry'];
    if (geom is! List || geom.isEmpty) return null;
    Map<String, dynamic>? latest;
    for (final g in geom) {
      if (g is Map<String, dynamic>) latest ??= g;
    }
    if (latest == null) return null;
    final coords = latest['coordinates'];
    if (coords is! List || coords.length < 2) return null;
    final lon = (coords[0] as num?)?.toDouble();
    final lat = (coords[1] as num?)?.toDouble();
    if (lon == null || lat == null) return null;

    return EonetEvent(
      id: id,
      title: title,
      category: category,
      opened: _tryDate(json['geometry'], latest, 'date'),
      closed: _tryDateClosed(json),
      latitude: lat,
      longitude: lon,
    );
  }

  static DateTime? _tryDate(dynamic geomList, Map<String, dynamic>? latest, String key) {
    final raw = latest?['date'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  static DateTime? _tryDateClosed(Map<String, dynamic> json) {
    final closed = json['closed'] as String?;
    if (closed == null) return null;
    return DateTime.tryParse(closed);
  }

  bool get isActive => closed == null;
}

/// EONET event categories, mapped to the subset relevant for Bangladesh.
enum EonetCategory {
  severeStorms,
  floods,
  earthquakes,
  wildfires,
  volcanoes,
  landslides,
  extremeTemperatures,
  drought,
  seaLakeIce,
  manmade,
  other;

  /// Map EONET category id → enum. EONET ids are stable slugs.
  static EonetCategory fromApi(String? id, String? title) {
    switch (id) {
      case 'severeStorms':
        return EonetCategory.severeStorms;
      case 'flood':
      case 'floods':
        return EonetCategory.floods;
      case 'earthquakes':
        return EonetCategory.earthquakes;
      case 'wildfires':
        return EonetCategory.wildfires;
      case 'volcanoes':
        return EonetCategory.volcanoes;
      case 'landslides':
        return EonetCategory.landslides;
      case 'tempExtremes':
        return EonetCategory.extremeTemperatures;
      case 'drought':
        return EonetCategory.drought;
      case 'seaLakeIce':
        return EonetCategory.seaLakeIce;
      case 'manmade':
        return EonetCategory.manmade;
      default:
        return EonetCategory.other;
    }
  }

  /// Material icon name for the category, used by the UI layer.
  String get iconKey => switch (this) {
        EonetCategory.severeStorms => 'storm',
        EonetCategory.floods => 'flood',
        EonetCategory.earthquakes => 'earthquake',
        EonetCategory.wildfires => 'fire',
        EonetCategory.volcanoes => 'volcano',
        EonetCategory.landslides => 'landslide',
        EonetCategory.extremeTemperatures => 'heat',
        EonetCategory.drought => 'drought',
        EonetCategory.seaLakeIce => 'ice',
        EonetCategory.manmade => 'manmade',
        EonetCategory.other => 'other',
      };

  /// Bangla label.
  String get labelBn => switch (this) {
        EonetCategory.severeStorms => 'ঘূর্ণিঝড়',
        EonetCategory.floods => 'বন্যা',
        EonetCategory.earthquakes => 'ভূমিকম্প',
        EonetCategory.wildfires => 'দাবানল',
        EonetCategory.volcanoes => 'আগ্নেয়গিরি',
        EonetCategory.landslides => 'ভূমিধস',
        EonetCategory.extremeTemperatures => 'তীব্র তাপ',
        EonetCategory.drought => 'খরা',
        EonetCategory.seaLakeIce => 'সমুদ্রের বরফ',
        EonetCategory.manmade => 'মানবসৃষ্ট',
        EonetCategory.other => 'অন্যান্য',
      };
}
