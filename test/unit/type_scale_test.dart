import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the type floor by reading the source, because the floor cannot be
/// enforced any other way.
///
/// `ShongjogTheme._build` sets a 17sp body floor and a 14sp caption floor on
/// `textTheme` — but an inline `style: TextStyle(fontSize: 11)` never touches
/// `textTheme` and walks straight past it. That is exactly what happened:
/// 114 literals below the caption floor had accumulated, outnumbering
/// compliant ones, with 13sp the single most common size in the app.
///
/// Bangla carries more vertical detail than Latin at the same point size —
/// conjuncts, matras and the headline stroke all compress — so small type
/// costs more here than it would in an English-only app. And Shongjog is read
/// outdoors, at night, by people in an emergency.
void main() {
  const floor = 14;

  /// Sizes below [floor] that are deliberate, with the reason they are exempt.
  ///
  /// Keep this list short and justified. "It looked better" is not a reason —
  /// if the text matters enough to show, it matters enough to read.
  const allowed = <String, String>{
    'lib/app/theme.dart':
        'NavigationBar labels. Material 3 specs navigation labels at 12sp, '
            'they are persistent chrome rather than content, and each is '
            'paired with a 26px icon that carries the affordance. Raising '
            'them overflows the 72px bar with five Bangla labels.',
  };

  final fontSize = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)');

  test('no source file sets a font size below the ${floor}sp caption floor',
      () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue,
        reason: 'Test must run from the project root.');

    final violations = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Generated localisations carry no styling.
      if (entity.path.contains('l10n')) continue;

      final relative = entity.path.replaceAll(r'\', '/');
      final lines = entity.readAsLinesSync();

      for (var i = 0; i < lines.length; i++) {
        for (final m in fontSize.allMatches(lines[i])) {
          final size = double.parse(m.group(1)!);
          if (size >= floor) continue;
          if (allowed.containsKey(relative)) continue;
          violations.add('$relative:${i + 1}  fontSize: ${m.group(1)}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Text below ${floor}sp is unreadable for the audience this app '
          'is built for. Raise it, or — if it is genuinely chrome rather than '
          'content — add the file to `allowed` above WITH a written reason.\n\n'
          '${violations.join('\n')}',
    );
  });

  test('every exemption names a real file, so the list cannot rot', () {
    for (final path in allowed.keys) {
      expect(File(path).existsSync(), isTrue,
          reason: '$path is exempted but no longer exists — remove the entry.');
    }
  });

  test('exempted files still contain a sub-floor size, so stale exemptions '
      'get noticed', () {
    for (final entry in allowed.entries) {
      final lines = File(entry.key).readAsLinesSync();
      final hasSubFloor = lines.any((l) => fontSize
          .allMatches(l)
          .any((m) => double.parse(m.group(1)!) < floor));
      expect(hasSubFloor, isTrue,
          reason: '${entry.key} is exempted but no longer has any sub-floor '
              'size. Drop the exemption.');
    }
  });
}
