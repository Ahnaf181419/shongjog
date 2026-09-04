import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every button in an [AlertDialog] action row must carry
/// `ShongjogTheme.dialogAction()`.
///
/// Guarded by reading the source, because no runtime assertion can see it.
/// `filledButtonTheme` sizes buttons with `Size.fromHeight(52)`, whose minimum
/// WIDTH is infinity — correct for a full-bleed CTA, and fatal inside a
/// dialog: `OverflowBar` cannot fit an infinitely-wide child beside anything,
/// so it abandons the row and stacks. Every confirm dialog in the app rendered
/// as a small 40dp "Cancel" on one line and a full-width 52dp confirm button
/// on the next — two controls that look unrelated, where the user is being
/// asked to choose between them.
///
/// `dialogAction()` pins a finite minimum width so the pair shares a row at
/// equal height. Forgetting it on a new dialog is silent and looks like a
/// layout accident rather than a missing style, hence a test.
void main() {
  final actionsBlock = RegExp(r'actions:\s*\[(.*?)\n\s*\],', dotAll: true);

  /// A button constructor that opens an action-row child — but not the
  /// `FilledButton.styleFrom(...)` that appears *inside* a `.merge(...)`,
  /// which is part of a style rather than a button of its own.
  final buttonOpen =
      RegExp(r'\b(?:Text|Filled|Outlined)Button(?:\.\w+)?\((?!\s*\))');
  final styleFrom = RegExp(r'\b\w+Button\.styleFrom\(');

  test('every dialog action button uses ShongjogTheme.dialogAction()', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue,
        reason: 'Test must run from the project root.');

    final violations = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.replaceAll(r'\', '/');
      if (relative.contains('/l10n/')) continue;

      final source = entity.readAsStringSync();
      for (final block in actionsBlock.allMatches(source)) {
        final body = block.group(1)!;
        // Buttons declared in this row, ignoring styleFrom calls.
        final buttons = buttonOpen.allMatches(body).length -
            styleFrom.allMatches(body).length;
        if (buttons <= 0) continue;
        final styled = 'dialogAction('.allMatches(body).length;
        if (styled < buttons) {
          final line = source.substring(0, block.start).split('\n').length;
          violations.add(
              '$relative:$line  $buttons action button(s), $styled styled');
        }
      }
    }

    expect(violations, isEmpty,
        reason: 'Add `style: ShongjogTheme.dialogAction(),` to these dialog '
            'action buttons (see docs/design.md §7.9), or `.merge()` it onto '
            'an existing style:\n${violations.join('\n')}');
  });
}
