import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shongjog/l10n/app_localizations.dart';

/// GDACS disaster-alerts client — UN/JRC global alerts feed.
///
/// GDACS (Global Disaster Alert and Coordination System) is a
/// cooperation framework between the UN and the European Commission.
/// It publishes near-real-time alerts for cyclones, earthquakes,
/// floods, volcanoes, and droughts with severity scoring
/// (Green / Orange / Red). Free, no key, open data.
///
/// Feed URL: https://www.gdacs.org/xml/rss.xml
/// Docs:    https://www.gdacs.org/
///
/// Used by the home screen to surface authoritative UN-grade alerts
/// currently active near Bangladesh — complements NASA EONET with
/// severity scoring and official alert levels. Degrades to null when
/// offline.
class GdacsService {
  static const _timeout = Duration(seconds: 10);

  /// Bangladesh bounding box (loose). GDACS items carry lat/lon as
  /// georss:point; we filter to within this box after parsing.
  static const double _minLat = 18.0;
  static const double _maxLat = 28.0;
  static const double _minLon = 87.0;
  static const double _maxLon = 95.0;

  /// Fetch and parse the GDACS RSS feed, returning alerts within the
  /// Bangladesh bounding box. Empty list if the feed parses but no
  /// alert is in the region; null on offline / transport / parse failure.
  static Future<List<GdacsAlert>?> fetchBangladeshAlerts({
    bool isOnline = true,
  }) async {
    if (!isOnline) return null;
    final uri = Uri.parse('https://www.gdacs.org/xml/rss.xml');
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
      return _parseRss(body);
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

  /// Parse the GDACS RSS XML and filter to Bangladesh.
  /// Exposed for unit testing.
  @visibleForTesting
  static List<GdacsAlert>? parseRssForTest(String xmlBody) => _parseRss(xmlBody);

  static List<GdacsAlert>? _parseRss(String xml) {
    // Lightweight regex parse — avoids pulling in an XML dependency
    // for a single feed. GDACS RSS items are flat and predictable.
    final itemRegex = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false);
    final items = itemRegex.allMatches(xml);
    final out = <GdacsAlert>[];
    for (final match in items) {
      final block = match.group(1) ?? '';
      final alert = GdacsAlert.tryParse(block);
      if (alert == null) continue;
      if (!_inBangladeshBox(alert.latitude, alert.longitude)) continue;
      out.add(alert);
    }
    return out;
  }

  static bool _inBangladeshBox(double lat, double lon) =>
      lat >= _minLat &&
      lat <= _maxLat &&
      lon >= _minLon &&
      lon <= _maxLon;
}

/// A single GDACS alert.
class GdacsAlert {
  final String title;
  final String? description;
  final String? link;
  final DateTime? pubDate;
  final double latitude;
  final double longitude;
  final GdacsSeverity severity;

  const GdacsAlert({
    required this.title,
    this.description,
    this.link,
    this.pubDate,
    required this.latitude,
    required this.longitude,
    required this.severity,
  });

  /// Parse a single `item` block. Returns null if required
  /// fields are missing (title, georss:point).
  static GdacsAlert? tryParse(String block) {
    final title = _tag(block, 'title');
    if (title == null || title.isEmpty) return null;

    // georss:point is "lat lon" (space-separated).
    final geopt = _tag(block, 'georss:point') ?? _tag(block, 'point');
    if (geopt == null) return null;
    final parts = geopt.trim().split(RegExp(r'[\s,]+'));
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0]);
    final lon = double.tryParse(parts[1]);
    if (lat == null || lon == null) return null;

    final pub = _tag(block, 'pubDate');
    DateTime? pubDate;
    if (pub != null) {
      pubDate = _tryParseRfc822(pub);
    }

    return GdacsAlert(
      title: title,
      description: _tag(block, 'description'),
      link: _tag(block, 'link'),
      pubDate: pubDate,
      latitude: lat,
      longitude: lon,
      severity: parseGdacsSeverity(block),
    );
  }

  /// RFC-822 date parser for RSS pubDate values like
  /// "Wed, 24 Jul 2026 12:00:00 GMT". Dart's DateTime.parse can't
  /// handle this format, so we hand-parse the month abbreviation and
  /// build an ISO string.
  static DateTime? _tryParseRfc822(String raw) {
    final months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    // Strip the weekday + comma, then split.
    final withoutWeekday = raw.contains(',')
        ? raw.substring(raw.indexOf(',') + 1).trim()
        : raw.trim();
    final parts = withoutWeekday.split(RegExp(r'\s+'));
    if (parts.length < 5) return null;
    final day = int.tryParse(parts[0]);
    final month = months[parts[1]];
    final year = int.tryParse(parts[2]);
    final timeParts = parts[3].split(':');
    if (day == null || month == null || year == null || timeParts.length < 3) {
      return null;
    }
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    final second = int.tryParse(timeParts[2]);
    if (hour == null || minute == null || second == null) return null;
    // Normalise 2-digit years (some feeds use them).
    final fullYear = year < 100 ? (year < 70 ? 2000 + year : 1900 + year) : year;
    // Build as UTC; the zone in parts[4] (GMT etc.) is good enough for
    // a pubDate that's only used for sorting.
    return DateTime.utc(fullYear, month, day, hour, minute, second);
  }

  static String? _tag(String block, String name) =>
      tryParseTag(block, name);

  /// Public tag extractor used by both [tryParse] and the severity
  /// parser. Exposed so [parseGdacsSeverity] can read the same
  /// `gdacs:alertlevel` block without duplicating the regex.
  static String? tryParseTag(String block, String name) {
    final m = RegExp(
      '<$name[^>]*>([\\s\\S]*?)</$name>',
      caseSensitive: false,
    ).firstMatch(block);
    return m?.group(1)?.trim().replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '');
  }
}

/// GDACS severity levels, derived from the `gdacs:alertlevel` tag.
enum GdacsSeverity { green, orange, red, unknown }

/// Parse the severity from an RSS `item` block.
GdacsSeverity parseGdacsSeverity(String block) {
  final raw = GdacsAlert.tryParseTag(block, 'gdacs:alertlevel') ??
      GdacsAlert.tryParseTag(block, 'alertlevel') ??
      '';
  switch (raw.toLowerCase()) {
    case 'green':
      return GdacsSeverity.green;
    case 'orange':
      return GdacsSeverity.orange;
    case 'red':
      return GdacsSeverity.red;
    default:
      return GdacsSeverity.unknown;
  }
}

extension GdacsSeverityLabel on GdacsSeverity {
  String label(BuildContext context) => switch (this) {
        GdacsSeverity.green => AppLocalizations.of(context).severityGreen,
        GdacsSeverity.orange => AppLocalizations.of(context).severityOrange,
        GdacsSeverity.red => AppLocalizations.of(context).severityRed,
        GdacsSeverity.unknown => AppLocalizations.of(context).severityUnknown,
      };
}
