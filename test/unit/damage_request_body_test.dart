import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/damage_scanner/damage_scan_service.dart';

/// The vision request is the app's slowest network call — it carries a photo.
/// These pin the two knobs that decide how long a scan takes, both of which
/// were missing and neither of which is visible at the call site.
void main() {
  final bytes = Uint8List.fromList(List<int>.filled(64, 7));

  test('thinking is suppressed', () {
    // Without this the model spends latency and output budget on
    // chain-of-thought before emitting five short JSON fields that the user
    // never sees it reason about.
    final cfg = DamageScanService.buildRequestBody(bytes)['generationConfig']
        as Map<String, dynamic>;
    expect(cfg['thinkingConfig'], {'thinkingBudget': 0});
  });

  test('JSON is requested rather than hoped for', () {
    final cfg = DamageScanService.buildRequestBody(bytes)['generationConfig']
        as Map<String, dynamic>;
    expect(cfg['responseMimeType'], 'application/json');
  });

  test('the whole body is UTF-8 encodable', () {
    // The prompt is Bangla. A latin1 encoding path threw before a single
    // byte reached the network — see the note in damage_scan_screen.dart.
    final body = DamageScanService.buildRequestBody(bytes);
    expect(() => utf8.encode(jsonEncode(body)), returnsNormally);
  });

  test('the image still rides as inline base64', () {
    final body = DamageScanService.buildRequestBody(bytes);
    final parts = (body['contents'] as List).first['parts'] as List;
    final inline = parts.last['inline_data'] as Map<String, dynamic>;
    expect(inline['mime_type'], 'image/jpeg');
    expect(base64Decode(inline['data'] as String), bytes);
  });
}
