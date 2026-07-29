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
    // attempt + one last-resort Gemma attempt. Bounded — the point is that it
    // terminates rather than spinning. Rotation is NOT re-run per model: the
    // ring is walked once, on the primary, and the two later models inherit
    // whichever key it ended on. That is what keeps this 7 and not 12.
    expect(calls, lessThanOrEqualTo(7));
    expect(calls, greaterThanOrEqualTo(4));
  });

  test('falls through to the last-resort Gemma model when both Gemini models '
      'are gone, and strips its scratchpad before returning', () async {
    final modelsTried = <String>[];
    final client = MockClient((req) async {
      final model = req.url.pathSegments.last.split(':').first;
      modelsTried.add(model);
      if (model != CloudAiService.lastResortModelId) {
        return http.Response(quotaBody, 429);
      }
      // Shaped like a real Gemma response: English planning bullets, then
      // the Bangla answer. Only the answer may reach the user.
      return ok('*   User asks: what to do in a flood.\n'
          '*   Language: Bangla.\n'
          '\n'
          'বন্যার সময় দ্রুত উঁচু ও নিরাপদ স্থানে আশ্রয় নিন।');
    });

    final svc = CloudAiService(
      keys: ApiKeyRing(keys: ['k1', 'k2']),
      httpClient: client,
    );

    final answer = await svc.generate('বন্যায় কী করব?');

    expect(answer, 'বন্যার সময় দ্রুত উঁচু ও নিরাপদ স্থানে আশ্রয় নিন।');
    expect(answer, isNot(contains('User asks')),
        reason: 'Gemma reasoning must never reach a user mid-emergency.');
    expect(modelsTried.last, CloudAiService.lastResortModelId);
    expect(modelsTried, contains(CloudAiService.primaryModelId));
    expect(modelsTried, contains(CloudAiService.fallbackModelId));
  });

  test('never sends thinkingConfig to the last-resort model — the API rejects '
      'the entire request with a 400 if it does', () async {
    final bodies = <String, String>{};
    final client = MockClient((req) async {
      final model = req.url.pathSegments.last.split(':').first;
      bodies[model] = req.body;
      if (model != CloudAiService.lastResortModelId) {
        return http.Response(quotaBody, 429);
      }
      return ok('উঁচু স্থানে যান। নিরাপদে থাকুন। সাহায্যের জন্য ফোন করুন।');
    });

    await CloudAiService(
      keys: ApiKeyRing(keys: ['k1']),
      httpClient: client,
    ).generate('প্রশ্ন');

    expect(bodies[CloudAiService.lastResortModelId], isNot(contains('thinking')));
    expect(bodies[CloudAiService.primaryModelId], contains('thinkingBudget'));
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
