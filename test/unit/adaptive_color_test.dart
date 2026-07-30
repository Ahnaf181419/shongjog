import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards that brightness-specific tokens are not used as if they adapted.
///
/// The original design audit checked whether the TOKEN PAIRS pass contrast.
/// They do. What it never checked was whether the adaptive tokens were
/// actually being used adaptively at the call sites — and they were not.
/// 35 sites painted `ShongjogTheme.ocean` directly.
///
/// `ocean` (#0369A1) is the LIGHT-mode primary. In dark mode it measures
/// 2.47:1 on `surfaceDark`, well under the 3:1 an icon needs and nowhere near
/// the 4.5:1 for text, and as an 8% tint it lands at 1.06:1 against the
/// background — invisible. `Theme.of(context).colorScheme.primary` resolves
/// to `ocean` in light and `oceanBright` in dark, which is the whole point of
/// having two.
///
/// Also pins the radius scale, which drifted back the moment new screens were
/// written — the token sweep fixed the existing call sites but nothing stopped
/// the next one.
void main() {
  /// Files allowed to name a brightness-specific token directly, with why.
  const colorExempt = <String, String>{
    'lib/app/theme.dart': 'defines the tokens',
    'lib/features/quick_cards/cards_data.dart':
        'const data list — no BuildContext exists at the definition site',
    'lib/features/shelter/widgets/user_marker.dart':
        'sits on map tiles, which never follow the app theme',
    'lib/features/shelter/widgets/shelter_marker.dart':
        'sits on map tiles, which never follow the app theme',
    'lib/features/chat/message_bubble.dart':
        'branches on brightness explicitly',
    'lib/features/settings/model_picker_section.dart':
        'branches on brightness explicitly',
    'lib/core/local_notification_service.dart':
        'notification tint — core/ does not depend on the theme layer, and a '
            'notification is drawn by the system shade, not our surfaces',
    'lib/features/splash/splash_screen.dart':
        'single-theme branded surface on a fixed gradient',
    'lib/features/shelter/widgets/offline_banner.dart':
        'floating pill that paints its own surfaceDark ground in BOTH themes, '
            'so oceanBright is the correct step there (6.83:1)',
  };

  /// Radius literals that are allowed off the 12/16/20 scale, with why.
  /// Small chips and dots are sub-surface elements; docs/design.md §5.4 locks
  /// SURFACES to the scale.
  const allowedRadii = {2, 4, 6, 8, 14, 24};

  Iterable<File> dartFiles() sync* {
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.dart') && !e.path.contains('l10n')) {
        yield e;
      }
    }
  }

  String rel(File f) => f.path.replaceAll(r'\', '/');

  test('brightness-specific tokens are not used where they cannot adapt', () {
    final token = RegExp(r'ShongjogTheme\.(ocean|oceanBright)\b');
    final offenders = <String>[];

    for (final f in dartFiles()) {
      final path = rel(f);
      if (colorExempt.containsKey(path)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Skip comments — several files legitimately name the token in prose.
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
        if (token.hasMatch(lines[i])) {
          offenders.add('$path:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'Use Theme.of(context).colorScheme.primary — it resolves to '
            'ocean in light and oceanBright in dark. Naming ocean directly '
            'gives 2.47:1 on the dark surface. If the surface genuinely does '
            'not follow the theme (a map tile, a fixed gradient), add the '
            'file to `colorExempt` WITH a reason.\n\n${offenders.join('\n')}');
  });

  test('surface radii stay on the 12/16/20 scale', () {
    final radius = RegExp(r'BorderRadius\.circular\((\d+)(?:\.0)?\)');
    final offenders = <String>[];

    for (final f in dartFiles()) {
      if (rel(f).endsWith('lib/app/theme.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in radius.allMatches(lines[i])) {
          final v = int.parse(m.group(1)!);
          if (allowedRadii.contains(v)) continue;
          offenders.add('${rel(f)}:${i + 1}  circular($v)');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'docs/design.md §5.4 locks surfaces to 12/16/20dp. Use '
            'ShongjogTheme.radiusSm / radius / radiusLg so the scale can move '
            'in one place.\n\n${offenders.join('\n')}');
  });

  test('every colour exemption names a file that still exists', () {
    for (final path in colorExempt.keys) {
      expect(File(path).existsSync(), isTrue,
          reason: '$path is exempted but no longer exists — remove the entry.');
    }
  });
}
