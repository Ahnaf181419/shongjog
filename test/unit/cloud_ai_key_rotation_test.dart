import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shongjog/core/connectivity_provider.dart';
import 'package:shongjog/features/cloud_ai/api_key_ring.dart';
import 'package:shongjog/features/cloud_ai/cloud_ai_service.dart';

/// End-to-end rotation: these drive the real [CloudAiService.generate] loop
/// through a mock transport and assert on the `x-goog-api-key` header of each
/// outgoing request, so they prove the *service* rotates — not just that the
/// ring can count.
void main() {
  setUp(() => connectivityProvider.debugSetOnline(true));
  tearDown(() => connectivityProvider.debugSetOnline(false));

  // Built via Response.bytes: the String constructor encodes with latin1
  // unless the content-type says otherwise, which silently cannot represent
  // Bangla and throws "Contains invalid characters".
  http.Response ok(String text) => http.Response.bytes(
        utf8.encode(jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': text},
                ],
              },
            },
          ],
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  const quotaBody =
      '{"error":{"code":429,"status":"RESOURCE_EXHAUSTED",'
      '"message":"Quota exceeded for quota metric"}}';

  test('rotates past keys whose daily quota is spent and answers on the '
      'first one that still works', () async {
    final keysUsed = <String>[];
    final client = MockClient((req) async {
      final key = req.headers['x-goog-api-key']!;
      keysUsed.add(key);
      // k1 and k2 are out of quota for the day; k3 still has budget.
      if (key == 'k1' || key == 'k2') {
        return http.Response(quotaBody, 429);
      }
      return ok('বন্যার পানি ফুটিয়ে পান করুন।');
    });

    final ring = ApiKeyRing(keys: ['k1', 'k2', 'k3', 'k4']);
    final svc = CloudAiService(keys: ring, httpClient: client);

    final answer = await svc.generate('পানি নিরাপদ?');

    expect(answer, 'বন্যার পানি ফুটিয়ে পান করুন।');
    expect(keysUsed, ['k1', 'k2', 'k3'],
        reason: 'must try each key in order, and stop at the first success');
    expect(ring.activeIndex, 2,
        reason: 'the working key sticks, so the next message starts there');
  });

  test('the sticky index means a second message goes straight to the working '
      'key instead of re-burning the dead ones', () async {
    final keysUsed = <String>[];
    final client = MockClient((req) async {
      final key = req.headers['x-goog-api-key']!;
      keysUsed.add(key);
      if (key == 'k1') return http.Response(quotaBody, 429);
      return ok('উত্তর');
    });

    final ring = ApiKeyRing(keys: ['k1', 'k2', 'k3']);
    final svc = CloudAiService(keys: ring, httpClient: client);

    await svc.generate('প্রথম');
    expect(keysUsed, ['k1', 'k2']);

    keysUsed.clear();
    await svc.generate('দ্বিতীয়');
    expect(keysUsed, ['k2'], reason: 'k1 is known-dead; do not retry it');
  });

  test('a 500 does NOT burn the ring — every key hits the same server fault, '
      'so it falls through to the fallback model on the same key', () async {
    final keysUsed = <String>[];
    final modelsUsed = <String>[];
    final client = MockClient((req) async {
      keysUsed.add(req.headers['x-goog-api-key']!);
      modelsUsed.add(req.url.pathSegments.last);
      if (modelsUsed.length == 1) {
        return http.Response('{"error":{"code":500}}', 500);
      }
      return ok('ফলব্যাক উত্তর');
    });

    final ring = ApiKeyRing(keys: ['k1', 'k2', 'k3', 'k4']);
    final svc = CloudAiService(keys: ring, httpClient: client);

    final answer = await svc.generate('প্রশ্ন');

    expect(answer, 'ফলব্যাক উত্তর');
    expect(keysUsed, ['k1', 'k1'], reason: 'no rotation on a server fault');
    expect(ring.activeIndex, 0);
    expect(modelsUsed.first, contains(CloudAiService.primaryModelId));
    expect(modelsUsed.last, contains(CloudAiService.fallbackModelId));
  });

  test('a blocked key rotates — this is the failure that actually took cloud '
      'AI down on this project', () async {
    final keysUsed = <String>[];
    final client = MockClient((req) async {
      final key = req.headers['x-goog-api-key']!;
      keysUsed.add(key);
      if (key == 'k1') {
        return http.Response(
            '{"error":{"code":403,"status":"PERMISSION_DENIED",'
            '"message":"API_KEY_SERVICE_BLOCKED"}}',
            403);
      }
      return ok('ঠিক আছে');
    });

    final svc = CloudAiService(
      keys: ApiKeyRing(keys: ['k1', 'k2']),
      httpClient: client,
    );

    expect(await svc.generate('প্রশ্ন'), 'ঠিক আছে');
    expect(keysUsed, ['k1', 'k2']);
  });

  test('when every key is spent it gives up instead of looping, and the '
      'caller falls through to on-device Gemma / the corpus', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return http.Response(quotaBody, 429);
    });

    final svc = CloudAiService(
      keys: ApiKeyRing(keys: ['k1', 'k2', 'k3', 'k4']),
      httpClient: client,
    );

    await expectLater(
      svc.generate('প্রশ্ন'),
      throwsA(isA<CloudAiUnavailableException>()),
    );
    // 4 keys on the primary model + one 2s burst retry + one fallback-model
    // attempt. Bounded — the point is it terminates rather than spinning.
    expect(calls, lessThanOrEqualTo(6));
    expect(calls, greaterThanOrEqualTo(4));
  });

  test('an empty ring fails fast rather than sending a blank credential',
      () async {
    final client = MockClient((req) async {
      fail('no request should be attempted with no keys');
    });
    final svc =
        CloudAiService(keys: ApiKeyRing(keys: const []), httpClient: client);

    expect(svc.hasKey, isFalse);
    await expectLater(
      svc.generate('প্রশ্ন'),
      throwsA(isA<CloudAiUnavailableException>()),
    );
  });
}
