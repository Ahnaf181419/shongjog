import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/home/home_screen.dart';

void main() {
  Widget wrapHome({ValueChanged<int>? onNavigateToTab}) {
    return MaterialApp(
      home: HomeScreen(onNavigateToTab: onNavigateToTab),
      routes: {
        '/settings': (_) => const Scaffold(body: Center(child: Text('Settings'))),
        '/emergency-contacts': (_) =>
            const Scaffold(body: Center(child: Text('Contacts'))),
        '/mesh-radar': (_) =>
            const Scaffold(body: Center(child: Text('Radar'))),
      },
    );
  }

  group('HomeScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(wrapHome());
      await tester.pumpAndSettle();
      expect(find.text('সংযোগ'), findsOneWidget);
    });

    testWidgets('renders bento grid tiles', (tester) async {
      await tester.pumpWidget(wrapHome());
      await tester.pumpAndSettle();
      expect(find.text('প্রশ্ন করুন'), findsOneWidget);
      expect(find.text('জরুরি কার্ড'), findsOneWidget);
      expect(find.text('জরুরি কল'), findsOneWidget);
      expect(find.text('নিকটস্থ আশ্রয়'), findsOneWidget);
      expect(find.text('সেটিংস'), findsOneWidget);
    });

    testWidgets('renders status pills', (tester) async {
      await tester.pumpWidget(wrapHome());
      await tester.pumpAndSettle();
      expect(find.text('অফলাইনে চলে'), findsOneWidget);
      expect(find.text('তথ্য প্রস্তুত'), findsOneWidget);
    });

    testWidgets('renders tip card after scrolling', (tester) async {
      await tester.pumpWidget(wrapHome());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('আজকের পরামর্শ'),
        200,
      );
      expect(find.text('আজকের পরামর্শ'), findsOneWidget);
    });

    testWidgets('calls onNavigateToTab when AI tile tapped', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        wrapHome(onNavigateToTab: (i) => tappedIndex = i),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('প্রশ্ন করুন'));
      expect(tappedIndex, 1);
    });

    testWidgets('calls onNavigateToTab when cards tile tapped', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        wrapHome(onNavigateToTab: (i) => tappedIndex = i),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('জরুরি কার্ড'));
      expect(tappedIndex, 2);
    });

    testWidgets('calls onNavigateToTab when shelter tile tapped', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        wrapHome(onNavigateToTab: (i) => tappedIndex = i),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('নিকটস্থ আশ্রয়'));
      expect(tappedIndex, 3);
    });
  });
}
