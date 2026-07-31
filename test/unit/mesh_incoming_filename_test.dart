import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/mesh_comm/mesh_models.dart';
import 'package:shongjog/features/mesh_comm/mesh_service.dart';

/// A peer-supplied filename hint must never be able to influence the path a
/// received file lands on — only, at most, its extension.
///
/// The receiver used to concatenate the peer's basename straight onto the app
/// documents directory. That directory also holds `model_<variant>.litertlm`,
/// so a connected peer could overwrite the on-device Gemma weights (a name
/// anyone can read off this repo) and silently destroy offline AI, or escape
/// upward with `../` into shared_prefs. These tests pin the property that
/// makes that impossible: the extension is the only thing that survives, and
/// it survives only if it is on an allowlist.
void main() {
  group('safeExtensionFor rejects path control', () {
    const attacks = <String>[
      'model_e2b.litertlm',
      '../model_e2b.litertlm',
      '../../../../data/data/dev.frostflux.shongjog/shared_prefs/x.xml',
      r'..\..\windows\style.exe',
      '/absolute/path/payload.sh',
      '..',
      '.',
      '',
      'no_extension_at_all',
      'trailing.dot.',
      'shell.jpg;rm -rf /',
    ];

    for (final hint in attacks) {
      test('"$hint" yields a safe, allowlisted extension', () {
        for (final type in [
          MessageType.voice,
          MessageType.image,
          MessageType.video,
        ]) {
          final ext = MeshService.safeExtensionFor(hint, type);
          expect(ext, isNot(contains('/')));
          expect(ext, isNot(contains(r'\')));
          expect(ext, isNot(contains('.')));
          expect(ext, isNotEmpty);
          // The resulting filename must stay a single path segment.
          final name = 'mesh_${type.name}_1.$ext';
          expect(name.split(RegExp(r'[/\\]')).length, 1,
              reason: 'hint "$hint" escaped its path segment as "$name"');
        }
      });
    }
  });

  group('safeExtensionFor honours legitimate extensions', () {
    test('keeps a recognised voice extension', () {
      expect(MeshService.safeExtensionFor('note.wav', MessageType.voice), 'wav');
      expect(MeshService.safeExtensionFor('a.OPUS', MessageType.voice), 'opus');
    });

    test('keeps a recognised image extension', () {
      expect(MeshService.safeExtensionFor('x.png', MessageType.image), 'png');
      expect(MeshService.safeExtensionFor('x.JPEG', MessageType.image), 'jpeg');
    });

    test('keeps a recognised video extension', () {
      expect(MeshService.safeExtensionFor('clip.mp4', MessageType.video), 'mp4');
    });

    test('falls back to the type default when the extension is foreign', () {
      // .litertlm is the model file — the exact thing this guards.
      expect(MeshService.safeExtensionFor('model_e2b.litertlm',
          MessageType.voice), 'm4a');
      expect(MeshService.safeExtensionFor('x.xml', MessageType.image), 'jpg');
      expect(MeshService.safeExtensionFor('x.mp4', MessageType.image), 'jpg');
    });

    test('a directory traversal carrying a valid extension still cannot '
        'carry the directory', () {
      // The extension is legitimate; the path is not. We take the former.
      expect(
        MeshService.safeExtensionFor('../../secrets/leak.png',
            MessageType.image),
        'png',
      );
    });
  });
}
