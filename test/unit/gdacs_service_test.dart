import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/hazards/gdacs_service.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {

  group('GdacsService', () {
    test('returns null when offline', () async {
      final result = await GdacsService.fetchBangladeshAlerts(isOnline: false);
      expect(result, isNull);
    });
  });

  group('GdacsService.parseRssForTest', () {
    test('parses a cyclone alert inside the Bangladesh box', () {
      const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title>GCDDS CYCLONE 01 near Bangladesh coast</title>
      <description>Developing cyclone, winds 120 km/h.</description>
      <link>https://www.gdacs.org/...</link>
      <pubDate>Wed, 24 Jul 2026 12:00:00 GMT</pubDate>
      <georss:point>22.0 91.0</georss:point>
      <gdacs:alertlevel>Orange</gdacs:alertlevel>
    </item>
  </channel>
</rss>
''';
      final alerts = GdacsService.parseRssForTest(xml);
      expect(alerts, isNotNull);
      expect(alerts!.length, 1);
      final a = alerts.first;
      expect(a.title, 'GCDDS CYCLONE 01 near Bangladesh coast');
      expect(a.latitude, closeTo(22.0, 0.001));
      expect(a.longitude, closeTo(91.0, 0.001));
      expect(a.severity, GdacsSeverity.orange);
      expect(a.pubDate, isNotNull,
          reason: 'RFC-822 pubDate must parse.');
    });

    test('excludes alerts outside the Bangladesh bounding box', () {
      const xml = '''
<rss><channel>
  <item>
    <title>Pacific cyclone</title>
    <georss:point>15.0 140.0</georss:point>
    <gdacs:alertlevel>Red</gdacs:alertlevel>
  </item>
  <item>
    <title>Bangladesh flood</title>
    <georss:point>24.0 90.0</georss:point>
    <gdacs:alertlevel>Green</gdacs:alertlevel>
  </item>
</channel></rss>
''';
      final alerts = GdacsService.parseRssForTest(xml);
      expect(alerts, isNotNull);
      expect(alerts!.length, 1);
      expect(alerts.first.title, 'Bangladesh flood');
      expect(alerts.first.severity, GdacsSeverity.green);
    });

    test('returns empty list when feed has no items', () {
      const xml = '<rss><channel></channel></rss>';
      final alerts = GdacsService.parseRssForTest(xml);
      expect(alerts, isNotNull);
      expect(alerts, isEmpty);
    });

    test('skips items missing required georss:point', () {
      const xml = '''
<rss><channel>
  <item>
    <title>No location</title>
    <gdacs:alertlevel>Red</gdacs:alertlevel>
  </item>
  <item>
    <title>With location</title>
    <georss:point>23.0 90.5</georss:point>
  </item>
</channel></rss>
''';
      final alerts = GdacsService.parseRssForTest(xml);
      expect(alerts, isNotNull);
      expect(alerts!.length, 1);
      expect(alerts.first.title, 'With location');
      expect(alerts.first.severity, GdacsSeverity.unknown,
          reason: 'Missing alertlevel tag → unknown.');
    });

    test('handles CDATA-wrapped title', () {
      const xml = '''
<rss><channel>
  <item>
    <title><![CDATA[Heavy rain alert: 400mm expected]]></title>
    <georss:point>22.5 91.5</georss:point>
    <gdacs:alertlevel>Red</gdacs:alertlevel>
  </item>
</channel></rss>
''';
      final alerts = GdacsService.parseRssForTest(xml);
      expect(alerts, isNotNull);
      expect(alerts!.length, 1);
      expect(alerts.first.title, 'Heavy rain alert: 400mm expected');
      expect(alerts.first.severity, GdacsSeverity.red);
    });
  });

  group('GdacsSeverity.label', () {
    testWidgets('every severity has a non-empty label', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          ctx = context;
          return const SizedBox();
        }),
      ));
      for (final s in GdacsSeverity.values) {
        expect(s.label(ctx).isNotEmpty, isTrue);
      }
    });
  });
}
