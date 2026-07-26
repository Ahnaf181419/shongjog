import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shongjog/l10n/app_localizations.dart';

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
  ///
  /// Tightened from the original [88.0, 27.5, 93.5, 20.0], which extended
  /// a full degree-plus past Bangladesh's real north/east borders (max
  /// ~26.65°N, ~92.7°E) — deep enough into Meghalaya, Assam, Tripura, and
  /// Myanmar to regularly surface those countries' hazards as if they were
  /// Bangladesh's. `south` is kept low on purpose: Bay of Bengal cyclones
  /// approaching Bangladesh are legitimately relevant before landfall.
  static const List<double> bangladeshBbox = [88.0, 26.7, 92.7, 19.5];

  /// Countries EONET titles occasionally do name directly (unlike storm
  /// events, which are just named after the storm with no place — "Tropical
  /// Cyclone Amphan" mentions no country at all). When a title clearly
  /// names one of these instead of Bangladesh, exclude it even if its
  /// point falls inside the (necessarily loose) bbox above. This is a
  /// weaker filter than requiring "Bangladesh" to be present — EONET
  /// often doesn't say the country either way — but still catches an
  /// explicitly-wrong-country title like "Flooding in Assam, India".
  static const _neighboringCountries = [
    'india', 'myanmar', 'nepal', 'bhutan', 'china', 'pakistan',
  ];

  /// Whether [title] names a neighboring country without also naming
  /// Bangladesh. Exposed for testing.
  @visibleForTesting
  static bool namesOtherCountry(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('bangladesh')) return false;
    return _neighboringCountries.any(lower.contains);
  }

  /// Hazard categories that genuinely reach across a national border, and
  /// so stay relevant to a Bangladeshi user even when the event is filed
  /// under a neighbouring country.
  ///
  /// A cyclone in the Bay of Bengal, a flood on a trans-boundary river
  /// (Ganges/Brahmaputra/Meghna all enter from India), or an earthquake in
  /// Meghalaya are all felt inside Bangladesh regardless of which country
  /// EONET names. A wildfire is not: it burns where it burns. Everything
  /// outside this set therefore still requires the title to name Bangladesh
  /// — which is what stops the card filling up with Indian wildfires that
  /// happen to fall inside the (unavoidably rectangular) bbox.
  static const crossBorderCategories = <EonetCategory>{
    EonetCategory.severeStorms,
    EonetCategory.floods,
    EonetCategory.earthquakes,
  };

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
    final client = http.Client();
    try {
      final res = await client.get(uri).timeout(_timeout);
      if (res.statusCode != 200) {
        debugPrint('[Eonet] non-200 status: ${res.statusCode}');
        return null;
      }
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) return null;
      final events = json['events'];
      if (events is! List) return null;
      return events
          .map((e) => EonetEvent.tryParse(e as Map<String, dynamic>))
          .whereType<EonetEvent>()
          .where((e) =>
              !e.isCrossBorder || crossBorderCategories.contains(e.category))
          .toList();
    } on TimeoutException {
      debugPrint('[Eonet] request timed out after ${_timeout.inSeconds}s');
      return null;
    } catch (e) {
      debugPrint('[Eonet] fetchOpenHazards failed: $e');
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
    // EONET returns geometry points in chronological order, so the LAST
    // map in the list is the most recent position. `latest ??= g` only
    // ever assigns once (on the first non-null match) and then never
    // updates again — despite the "take the most recent" comment above,
    // it was actually keeping the FIRST point. For a multi-day tracked
    // event (a cyclone moving across days), that meant filtering and
    // display used a stale, possibly long-outdated position — e.g. a
    // storm's first known point near Bangladesh even after it had moved
    // into India or out to open sea days later.
    Map<String, dynamic>? latest;
    for (final g in geom) {
      if (g is Map<String, dynamic>) latest = g;
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

  /// Whether this event is filed under a neighbouring country rather than
  /// Bangladesh. Such events are still shown when their category crosses
  /// borders (see [EonetService.crossBorderCategories]), but the UI marks
  /// them so they're never mistaken for a hazard inside Bangladesh.
  bool get isCrossBorder => EonetService.namesOtherCountry(title);

  /// [title] with EONET's trailing numeric event id removed.
  ///
  /// EONET appends its internal id to many titles — "Wildfire in India,
  /// Bangladesh 1023636" — which reads as a glitch to a user. Stripped only
  /// for display; [title] stays intact so country filtering and tests keep
  /// working off the raw feed value.
  String get displayTitle =>
      title.replaceFirst(RegExp(r'\s+\d{5,}$'), '').trim();
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

  /// Localized label.
  String label(BuildContext context) => switch (this) {
        EonetCategory.severeStorms => AppLocalizations.of(context).hazardCyclone,
        EonetCategory.floods => AppLocalizations.of(context).hazardFlood,
        EonetCategory.earthquakes => AppLocalizations.of(context).hazardEarthquake,
        EonetCategory.wildfires => AppLocalizations.of(context).hazardWildfire,
        EonetCategory.volcanoes => AppLocalizations.of(context).hazardVolcano,
        EonetCategory.landslides => AppLocalizations.of(context).hazardLandslide,
        EonetCategory.extremeTemperatures => AppLocalizations.of(context).hazardExtremeHeat,
        EonetCategory.drought => AppLocalizations.of(context).hazardDrought,
        EonetCategory.seaLakeIce => AppLocalizations.of(context).hazardSeaIce,
        EonetCategory.manmade => AppLocalizations.of(context).hazardManmade,
        EonetCategory.other => AppLocalizations.of(context).hazardOther,
      };

  String get labelBn => switch (this) {
        EonetCategory.severeStorms => 'ঘূর্ণিঝড়',
        EonetCategory.floods => 'বন্যা',
        EonetCategory.earthquakes => 'ভূমিকম্প',
        EonetCategory.wildfires => 'দাবানল',
        EonetCategory.volcanoes => 'আগ্নেয়গিরি',
        EonetCategory.landslides => 'ভূমিধস',
        EonetCategory.extremeTemperatures => 'চরম তাপমাত্রা',
        EonetCategory.drought => 'খরা',
        EonetCategory.seaLakeIce => 'সমুদ্র/হ্রদের বরফ',
        EonetCategory.manmade => 'মানবসৃষ্ট',
        EonetCategory.other => 'অন্যান্য',
      };
}
