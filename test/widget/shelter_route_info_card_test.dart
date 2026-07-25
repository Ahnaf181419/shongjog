import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shongjog/features/shelter/shelter_model.dart';
import 'package:shongjog/features/shelter/widgets/shelter_route_info_card.dart';
import 'package:shongjog/l10n/app_localizations.dart';

const _shelter = Shelter(
  name: 'Khulna Shelter A',
  nameBn: 'খুলনা শেল্টার এ',
  lat: 22.85,
  lon: 89.55,
  capacity: 1200,
  source: 'MoDMR',
);

void main() {
  group('ShelterRouteInfoCard', () {
    testWidgets('shows the Bangla shelter name + capacity in the header',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShelterRouteInfoCard(
            selected: _shelter,
            loading: false,
            distanceKm: 14.25,
            onCancel: () {},
            onDetails: () {},
          ),
        ),
      ));

      expect(find.text('খুলনা শেল্টার এ'), findsOneWidget);
      expect(find.text('ধারণক্ষমতা: 1200 জন'), findsOneWidget);
    });

    testWidgets('shows the formatted distance in km when not loading',
        (tester) async {
      // Use a distance whose toStringAsFixed(1) result is unambiguous
      // and locale-independent: 5.0 → "5.0". The earlier 14.25 produced
      // "14.2" (banker's-rounding) in Dart, which is fragile against
      // future Dart changes.
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShelterRouteInfoCard(
            selected: _shelter,
            loading: false,
            distanceKm: 5.0,
            onCancel: () {},
            onDetails: () {},
          ),
        ),
      ));

      expect(find.text('5.0 কিমি'), findsOneWidget);
    });

    testWidgets('shows "—" placeholder when distance is null', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShelterRouteInfoCard(
            selected: _shelter,
            loading: false,
            distanceKm: null,
            onCancel: () {},
            onDetails: () {},
          ),
        ),
      ));

      expect(find.text('— কিমি'), findsOneWidget);
    });

    testWidgets('shows "রুট খুঁজছি…" + a CircularProgressIndicator when loading',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShelterRouteInfoCard(
            selected: _shelter,
            loading: true,
            distanceKm: null,
            onCancel: () {},
            onDetails: () {},
          ),
        ),
      ));

      expect(find.text('রুট খুঁজছি...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The distance label should NOT be visible during loading.
      expect(find.textContaining('কিমি'), findsNothing);
    });

    testWidgets('cancel + details buttons call the right callbacks',
        (tester) async {
      var cancelCount = 0;
      var detailsCount = 0;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShelterRouteInfoCard(
            selected: _shelter,
            loading: false,
            distanceKm: 14.25,
            onCancel: () => cancelCount++,
            onDetails: () => detailsCount++,
          ),
        ),
      ));

      await tester.tap(find.text('বাতিল'));
      await tester.tap(find.text('বিস্তারিত'));
      await tester.pump();

      expect(cancelCount, 1);
      expect(detailsCount, 1);
    });
  });
}
