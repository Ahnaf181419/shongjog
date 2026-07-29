import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shongjog/features/shelter/nearest_shelter.dart';
import 'package:shongjog/features/shelter/shelter_model.dart';
import 'package:shongjog/features/shelter/widgets/shelter_search_panel.dart';
import 'package:shongjog/l10n/app_localizations.dart';

const _shelters = [
  Shelter(
    name: 'Khulna Shelter A',
    nameBn: 'খুলনা শেল্টার এ',
    lat: 22.85,
    lon: 89.55,
    capacity: 1200,
    source: 'MoDMR',
  ),
  Shelter(
    name: 'Barisal Cyclone Shelter',
    nameBn: 'বরিশাল সাইক্লোন শেল্টার',
    lat: 22.70,
    lon: 90.40,
    capacity: 800,
    source: 'MoDMR',
  ),
];

/// Shelters carrying the new `division` field, used by the chip-row test.
const _sheltersWithDivisions = [
  Shelter(
    name: 'Khulna Cyclone Shelter 1',
    nameBn: 'খুলনা সাইক্লোন শেল্টার ১',
    lat: 22.85,
    lon: 89.55,
    capacity: 1200,
    division: 'khulna',
    type: 'cyclone',
    source: 'MoDMR',
  ),
  Shelter(
    name: 'Barisal Cyclone Shelter 1',
    nameBn: 'বরিশাল সাইক্লোন শেল্টার ১',
    lat: 22.70,
    lon: 90.40,
    capacity: 800,
    division: 'barishal',
    type: 'cyclone',
    source: 'MoDMR',
  ),
];

List<RankedShelter> _buildRanked() {
  // Use a known center so ranking is deterministic in the list order.
  final ranked = nearestShelters(
    lat: 22.85,
    lon: 89.55,
    all: _shelters,
    k: _shelters.length,
  );
  return ranked;
}

List<RankedShelter> _buildRankedWithDivisions() {
  return nearestShelters(
    lat: 22.85,
    lon: 89.55,
    all: _sheltersWithDivisions,
    k: _sheltersWithDivisions.length,
  );
}

void main() {
  group('ShelterSearchPanel', () {
    testWidgets('renders every ranked shelter by default (no filter)',
        (tester) async {
      var selectedShelter = const Shelter(
        name: 'none',
        nameBn: '',
        lat: 0,
        lon: 0,
        source: '',
      );
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShelterSearchPanel(
            ranked: _buildRanked(),
            onSelect: (r) => selectedShelter = r.shelter,
            onClose: () {},
          ),
        ),
      ));

      // Two rows visible — both shelters with their Bangla names.
      expect(find.text('খুলনা শেল্টার এ'), findsOneWidget);
      expect(find.text('বরিশাল সাইক্লোন শেল্টার'), findsOneWidget);
      // Empty-state message NOT visible.
      expect(find.text('কোনো আশ্রয়কেন্দ্র পাওয়া যায়নি'), findsNothing);
      expect(selectedShelter.name, 'none',
          reason: 'no row tapped yet');
    });

    testWidgets('filters by English name (case-insensitive substring)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShelterSearchPanel(
            ranked: _buildRanked(),
            onSelect: (_) {},
            onClose: () {},
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), 'barisal');
      await tester.pump();

      expect(find.text('খুলনা শেল্টার এ'), findsNothing);
      expect(find.text('বরিশাল সাইক্লোন শেল্টার'), findsOneWidget);
    });

    testWidgets('filters by Bangla name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShelterSearchPanel(
            ranked: _buildRanked(),
            onSelect: (_) {},
            onClose: () {},
          ),
        ),
      ));

      await tester.enterText(find.byType(TextField), 'খুলনা');
      await tester.pump();

      expect(find.text('খুলনা শেল্টার এ'), findsOneWidget);
      expect(find.text('বরিশাল সাইক্লোন শেল্টার'), findsNothing);
    });

    testWidgets(
      'shows empty-state message when no shelter matches the filter',
      (tester) async {
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ShelterSearchPanel(
              ranked: _buildRanked(),
              onSelect: (_) {},
              onClose: () {},
            ),
          ),
        ));

        await tester.enterText(find.byType(TextField), 'xyz不存在');
        await tester.pump();

        expect(find.text('কোনো আশ্রয়কেন্দ্র পাওয়া যায়নি'), findsOneWidget);
      },
    );

    testWidgets('tapping the suffix X clears input + fires onClose',
        (tester) async {
      var closeCount = 0;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShelterSearchPanel(
            ranked: _buildRanked(),
            onSelect: (_) {},
            onClose: () => closeCount++,
          ),
        ),
      ));

      // Type something, then tap the close (X) icon.
      await tester.enterText(find.byType(TextField), 'barisal');
      await tester.pump();
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(closeCount, 1,
          reason: 'tap on close should call onClose once');
    });

    testWidgets(
      'tapping a row invokes onSelect with the matching RankedShelter',
      (tester) async {
        RankedShelter? captured;
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('bn'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ShelterSearchPanel(
              ranked: _buildRanked(),
              onSelect: (r) => captured = r,
              onClose: () {},
            ),
          ),
        ));

        // Tap the Barisal row (the second one because Khulna is closest
        // to the center 22.85/89.55).
        await tester.tap(find.text('বরিশাল সাইক্লোন শেল্টার'));
        await tester.pump();

        expect(captured, isNotNull);
        expect(captured!.shelter.name, 'Barisal Cyclone Shelter');
      },
    );

    testWidgets('hides the division chip row when data has no divisions',
        (tester) async {
      // The legacy _shelters const has no `division` field, so the chip
      // row must not render at all.
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShelterSearchPanel(
            ranked: _buildRanked(),
            onSelect: (_) {},
            onClose: () {},
          ),
        ),
      ));

      // The Khulna chip label is 'খুলনা'; it must be absent here.
      expect(find.text('খুলনা'), findsNothing);
    });

    testWidgets('division chip narrows results to that division',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('bn'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ShelterSearchPanel(
            ranked: _buildRankedWithDivisions(),
            onSelect: (_) {},
            onClose: () {},
          ),
        ),
      ));

      // Both shelters visible initially.
      expect(find.text('খুলনা সাইক্লোন শেল্টার ১'), findsOneWidget);
      expect(find.text('বরিশাল সাইক্লোন শেল্টার ১'), findsOneWidget);

      // Tap the Khulna chip — target the FilterChip itself, not its Text
      // label, since the label is not directly hit-testable.
      await tester.tap(find.widgetWithText(FilterChip, 'খুলনা'));
      await tester.pump();

      expect(find.text('খুলনা সাইক্লোন শেল্টার ১'), findsOneWidget);
      expect(find.text('বরিশাল সাইক্লোন শেল্টার ১'), findsNothing,
          reason: 'Barisal filtered out by the Khulna chip');

      // Tapping "All" (সব) restores both.
      await tester.tap(find.widgetWithText(FilterChip, 'সব'));
      await tester.pump();
      expect(find.text('খুলনা সাইক্লোন শেল্টার ১'), findsOneWidget);
      expect(find.text('বরিশাল সাইক্লোন শেল্টার ১'), findsOneWidget);
    });
  });
}
