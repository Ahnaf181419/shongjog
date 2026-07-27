import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/cloud_ai/api_key_ring.dart';
import 'package:shongjog/features/cloud_ai/cloud_ai_service.dart';

void main() {
  group('ApiKeyRing', () {
    test('starts on the first key', () {
      final ring = ApiKeyRing(keys: ['a', 'b', 'c', 'd']);
      expect(ring.activeKey, 'a');
      expect(ring.activeIndex, 0);
      expect(ring.length, 4);
    });

    test('advance walks the ring in order and wraps', () {
      final ring = ApiKeyRing(keys: ['a', 'b', 'c', 'd'], startIndex: 2);
      expect(ring.activeKey, 'c');
      expect(ring.advance(), isTrue);
      expect(ring.activeKey, 'd');
      expect(ring.advance(), isTrue);
      expect(ring.activeKey, 'a', reason: 'must wrap past the end');
      expect(ring.advance(), isTrue);
      expect(ring.activeKey, 'b');
    });

    test('advance stops after one full lap, so an all-keys-exhausted request '
        'cannot spin forever', () {
      final ring = ApiKeyRing(keys: ['a', 'b', 'c', 'd']);
      ring.beginRequest();
      expect(ring.advance(), isTrue); // b
      expect(ring.advance(), isTrue); // c
      expect(ring.advance(), isTrue); // d
      expect(ring.advance(), isFalse, reason: 'all four tried');
      expect(ring.advance(), isFalse);
    });

    test('beginRequest gives the next message a fresh lap — one exhausted '
        'request must not permanently disable rotation', () {
      final ring = ApiKeyRing(keys: ['a', 'b']);
      ring.beginRequest();
      expect(ring.advance(), isTrue);
      expect(ring.advance(), isFalse);

      ring.beginRequest();
      expect(ring.advance(), isTrue);
    });

    test('a single-key ring never rotates', () {
      final ring = ApiKeyRing.single('only');
      ring.beginRequest();
      expect(ring.advance(), isFalse);
      expect(ring.activeKey, 'only');
    });

    test('reports the new index so the caller can persist it', () {
      final seen = <int>[];
      final ring = ApiKeyRing(
        keys: ['a', 'b', 'c'],
        onIndexChanged: seen.add,
      );
      ring.beginRequest();
      ring.advance();
      ring.advance();
      expect(seen, [1, 2]);
    });

    test('clamps an out-of-range startIndex instead of throwing — a stored '
        'index survives the ring shrinking when a key is removed', () {
      final ring = ApiKeyRing(keys: ['a', 'b'], startIndex: 7);
      expect(ring.activeIndex, 0);
      expect(ring.activeKey, 'a');
    });

    test('drops blank entries so a stray empty row in the console doc does '
        'not become a wasted rotation slot', () {
      final ring = ApiKeyRing(keys: ['a', '', '   ', 'b']);
      expect(ring.keys, ['a', 'b']);
    });

    test('an empty ring is empty, and reading a key from it throws rather '
        'than silently sending an empty credential', () {
      final ring = ApiKeyRing(keys: const []);
      expect(ring.isEmpty, isTrue);
      expect(() => ring.activeKey, throwsStateError);
    });
  });

  // Which failures justify spending another key is the whole design. Rotating
  // on a 500 or a timeout burns all four against a wall that has nothing to
  // do with credentials, and adds seconds to an emergency answer.
  group('CloudAiService.isKeyFatal', () {
    test('daily quota exhaustion rotates', () {
      expect(CloudAiService.isKeyFatal(Exception('HTTP 429: {"error":'
          '{"status":"RESOURCE_EXHAUSTED"}}')), isTrue);
    });

    test('a blocked or restricted key rotates', () {
      expect(
          CloudAiService.isKeyFatal(
              Exception('HTTP 403: API_KEY_SERVICE_BLOCKED')),
          isTrue);
      expect(CloudAiService.isKeyFatal(Exception('HTTP 403: SERVICE_DISABLED')),
          isTrue);
    });

    test('an invalid or wrong-type credential rotates — this is the shape of '
        'the expired AQ. token this project actually shipped', () {
      expect(CloudAiService.isKeyFatal(Exception('HTTP 400: API_KEY_INVALID')),
          isTrue);
      expect(
          CloudAiService.isKeyFatal(
              Exception('HTTP 401: ACCESS_TOKEN_TYPE_UNSUPPORTED')),
          isTrue);
    });

    test('a server-side fault does NOT rotate — every key hits it equally', () {
      expect(CloudAiService.isKeyFatal(Exception('HTTP 500: internal')),
          isFalse);
      expect(CloudAiService.isKeyFatal(Exception('HTTP 503: overloaded')),
          isFalse);
    });

    test('a timeout does NOT rotate — that is the network, not the key', () {
      expect(
          CloudAiService.isKeyFatal(
              Exception('TimeoutException after 0:00:10.000000')),
          isFalse);
    });

    test('a model-level rejection does NOT rotate', () {
      expect(
          CloudAiService.isKeyFatal(Exception(
              'HTTP 400: {"error":{"message":"Thinking budget is not '
              'supported for this model.","status":"INVALID_ARGUMENT"}}')),
          isFalse);
      expect(CloudAiService.isKeyFatal(Exception('HTTP 404: model not found')),
          isFalse);
    });

    test('matches case-insensitively', () {
      expect(CloudAiService.isKeyFatal(Exception('resource_exhausted')),
          isTrue);
    });
  });
}
