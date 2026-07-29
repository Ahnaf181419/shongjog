import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the icon set on one family.
///
/// The app draws from Material's *rounded* family, which is the right call:
/// rounded terminals match the 12/16/20dp corner radii in docs/design.md §5.4.
/// But 83 baseline icons had accumulated alongside them — refresh, check,
/// close, phone, mic, person. Baseline has square-cut stroke ends, so
/// next to a rounded icon in the same row it reads subtly wrong without the
/// viewer being able to say why.
///
/// Two exemptions, both deliberate:
///   * the bottom nav pairs `_outlined` (unselected) with `_rounded` (selected)
///     — that is the Material 3 selected-state pattern, not drift;
///   * `Icons.foggy` has no `_rounded` variant in the Material set at all.
void main() {
  const styleSuffixes = ['_rounded', '_outlined', '_sharp', '_two_tone'];

  /// Baseline icons with no rounded twin in the Material set. Adding to this
  /// list is a claim you have checked `Icons.<name>_rounded` does not exist.
  const noRoundedVariant = <String>{'foggy'};

  final iconRef = RegExp(r'\bIcons\.([a-z0-9_]+)');

  Iterable<File> dartFiles() sync* {
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.dart') && !e.path.contains('l10n')) {
        yield e;
      }
    }
  }

  test('no baseline icons outside the documented exemptions', () {
    final offenders = <String>[];

    for (final f in dartFiles()) {
      final rel = f.path.replaceAll(r'\', '/');
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in iconRef.allMatches(lines[i])) {
          final name = m.group(1)!;
          if (styleSuffixes.any(name.endsWith)) continue;
          if (noRoundedVariant.contains(name)) continue;
          offenders.add('$rel:${i + 1}  Icons.$name');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'These are baseline-family icons in a rounded-family app. '
            'Append `_rounded`, or — if no rounded variant exists — add the '
            'name to `noRoundedVariant` above.\n\n${offenders.join('\n')}');
  });

  test('_sharp and _two_tone are never used', () {
    final offenders = <String>[];
    for (final f in dartFiles()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in iconRef.allMatches(lines[i])) {
          final n = m.group(1)!;
          if (n.endsWith('_sharp') || n.endsWith('_two_tone')) {
            offenders.add('${f.path}:${i + 1}  Icons.$n');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Sharp and two-tone are a third and fourth visual language.');
  });

  test('_outlined is confined to the bottom nav selected-state pattern', () {
    // Outlined is legitimate ONLY as the unselected half of a nav pair. If it
    // starts appearing elsewhere, the app has drifted back to mixing families.
    final outsideNav = <String>[];
    for (final f in dartFiles()) {
      final rel = f.path.replaceAll(r'\', '/');
      if (rel.endsWith('lib/app/main_shell.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in iconRef.allMatches(lines[i])) {
          if (m.group(1)!.endsWith('_outlined')) {
            outsideNav.add('$rel:${i + 1}  Icons.${m.group(1)}');
          }
        }
      }
    }
    // Not asserted empty — outlined has legitimate uses for "empty state" and
    // secondary affordances. This pins the COUNT so a silent creep upward
    // shows up in review as a deliberate number change.
    expect(outsideNav.length, lessThanOrEqualTo(30),
        reason: 'Outlined icons outside the nav have grown past the level '
            'reviewed when the family was consolidated:\n'
            '${outsideNav.join('\n')}');
  });

  test('the bottom nav still pairs outlined with rounded per tab', () {
    final src = File('lib/app/main_shell.dart').readAsStringSync();
    final selected = RegExp(r'selectedIcon:\s*Icon\(Icons\.(\w+)\)')
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toList();
    final unselected = RegExp(r'\n\s*icon:\s*Icon\(Icons\.(\w+)\)')
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toList();

    expect(selected, isNotEmpty);
    expect(selected.length, unselected.length,
        reason: 'Every tab needs both a selected and an unselected icon.');

    for (var i = 0; i < selected.length; i++) {
      expect(selected[i], endsWith('_rounded'),
          reason: 'Selected tab icons are filled/rounded.');
      expect(unselected[i], endsWith('_outlined'),
          reason: 'Unselected tab icons are outlined.');
      expect(selected[i].replaceAll('_rounded', ''),
          unselected[i].replaceAll('_outlined', ''),
          reason: 'The pair must be two styles of the SAME glyph.');
    }
  });
}
