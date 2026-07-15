import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/chat/typewriter_text.dart';

void main() {
  group('TypewriterText', () {
    testWidgets('shows full text immediately when animate is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypewriterText(
              text: 'হ্যালো',
              animate: false,
            ),
          ),
        ),
      );

      final richText = tester.widget<RichText>(find.byType(RichText));
      final span = richText.text as TextSpan;
      expect(span.text, 'হ্যালো');
    });

    testWidgets('starts with partial text when animate is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypewriterText(
              text: 'একটি দীর্ঘ বাংলা বাক্য',
              animate: true,
              stepDuration: const Duration(milliseconds: 500),
            ),
          ),
        ),
      );

      // After first frame, text should be 0 chars
      final richText = tester.widget<RichText>(find.byType(RichText));
      final span = richText.text as TextSpan;
      expect(span.text, isEmpty);
    });

    testWidgets('reveals all text after enough time', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypewriterText(
              text: 'ABC',
              animate: true,
              stepDuration: const Duration(milliseconds: 5),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      final span = richText.text as TextSpan;
      expect(span.text, 'ABC');
    });

    testWidgets('calls onComplete callback', (tester) async {
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypewriterText(
              text: 'ABC',
              animate: true,
              stepDuration: const Duration(milliseconds: 5),
              onComplete: () => completed = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });

    testWidgets('does not re-animate after completion when parent rebuilds', (tester) async {
      var animationCount = 0;

      // Use a StatefulWidget parent that can trigger rebuilds
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    TypewriterText(
                      text: 'Hello',
                      animate: true,
                      stepDuration: const Duration(milliseconds: 5),
                      onComplete: () => animationCount++,
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Rebuild'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Let initial animation complete
      await tester.pumpAndSettle();
      expect(animationCount, 1);

      // Trigger parent rebuild
      await tester.tap(find.text('Rebuild'));
      await tester.pumpAndSettle();

      // Animation should NOT have run again
      expect(animationCount, 1);
    });
  });
}
