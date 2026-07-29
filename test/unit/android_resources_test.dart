import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/core/local_notification_service.dart';

/// Guards that Android resource names referenced from Dart actually exist.
///
/// `LocalNotificationService` asked for `@mipmap/ic_launcher` for months. That
/// resource has never existed in this project — the launcher icon is named
/// `launcher_icon`. Android resolves a missing identifier to 0, and posting a
/// notification with `setSmallIcon(0)` is rejected outright with "Invalid
/// notification (no valid small icon)".
///
/// Nothing caught it: the name is a string, the failure is on the platform
/// side, and the Dart unit tests use `debugSinkOverride` so they never touch
/// the real channel. A filesystem check is the only cheap way to pin it.
void main() {
  const resDir = 'android/app/src/main/res';

  /// Resolve an `@type/name` reference to the directories that would satisfy
  /// it — Android matches `type` plus any density qualifier suffix.
  List<String> resolve(String reference) {
    final match = RegExp(r'^@(\w+)/(\w+)$').firstMatch(reference);
    expect(match, isNotNull,
        reason: '"$reference" is not a valid @type/name reference.');
    final type = match!.group(1)!;
    final name = match.group(2)!;

    final root = Directory(resDir);
    if (!root.existsSync()) return const [];

    return root
        .listSync()
        .whereType<Directory>()
        .where((d) {
          final base = d.path.split(Platform.pathSeparator).last;
          return base == type || base.startsWith('$type-');
        })
        .where((d) => d
            .listSync()
            .whereType<File>()
            .any((f) {
              final file = f.path.split(Platform.pathSeparator).last;
              return file == '$name.png' ||
                  file == '$name.xml' ||
                  file == '$name.webp';
            }))
        .map((d) => d.path.split(Platform.pathSeparator).last)
        .toList()
      ..sort();
  }

  test('the notification small icon resource exists', () {
    final dirs = resolve(LocalNotificationService.smallIcon);
    expect(dirs, isNotEmpty,
        reason: '${LocalNotificationService.smallIcon} resolves to no file '
            'under $resDir. Android will resolve it to id 0 and refuse to '
            'post the notification.');
  });

  test('the small icon ships at every density, so it is not upscaled in the '
      'status bar', () {
    final dirs = resolve(LocalNotificationService.smallIcon);
    for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      expect(dirs.any((d) => d.endsWith('-$density')), isTrue,
          reason: 'Missing the $density variant. Found: $dirs');
    }
  });

  test('the small icon is NOT the launcher icon', () {
    // Android renders a small icon's alpha channel only and tints it, so a
    // full-colour launcher icon collapses to a solid white blob.
    expect(LocalNotificationService.smallIcon, isNot(contains('launcher')),
        reason: 'Use a dedicated monochrome silhouette, not the app icon.');
  });

  group('adaptive launcher icon', () {
    // minSdk is 26, so every device this ships to uses an adaptive-icon
    // launcher. Without these, the launcher shrinks the legacy PNG onto a
    // white plate instead of drawing it edge to edge.
    test('the adaptive icon XML exists', () {
      expect(File('$resDir/mipmap-anydpi-v26/launcher_icon.xml').existsSync(),
          isTrue,
          reason: 'No adaptive icon — run `dart run flutter_launcher_icons`.');
    });

    test('it declares both a background and a foreground layer', () {
      final xml =
          File('$resDir/mipmap-anydpi-v26/launcher_icon.xml').readAsStringSync();
      expect(xml, contains('<background'));
      expect(xml, contains('<foreground'));
    });

    test('the foreground drawable it points at exists', () {
      expect(resolve('@drawable/ic_launcher_foreground'), isNotEmpty);
    });

    test('the legacy mipmap carries alpha, not baked-in black corners', () {
      // The original source was RGB with no alpha, so everything outside the
      // squircle was flattened to pure black and shipped as black corners.
      final f = File('$resDir/mipmap-xxxhdpi/launcher_icon.png');
      expect(f.existsSync(), isTrue);
      final bytes = f.readAsBytesSync();
      // PNG colour type lives at byte 25 of the IHDR chunk: 6 = RGBA, 4 =
      // grey+alpha, 3 = palette (may carry tRNS), 2 = RGB with no alpha.
      final colourType = bytes[25];
      expect(colourType, isNot(2),
          reason: 'launcher_icon.png is RGB with no alpha channel, which is '
              'how the black corners got baked in.');
    });
  });
}
