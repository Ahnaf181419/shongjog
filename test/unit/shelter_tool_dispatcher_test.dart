import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/shelter/shelter_model.dart';
import 'package:shongjog/features/shelter/shelter_tool_dispatcher.dart';

void main() {
  // Three shelters at known distances from the reference point (0, 0).
  // We use small synthetic coordinates so distances are easy to reason
  // about; the haversine formula is exercised for real.
  final shelters = [
    const Shelter(
        name: 'Far',
        nameBn: 'দূরের',
        lat: 0.5,
        lon: 0.5,
        capacity: 1000,
        source: 'test'),
    const Shelter(
        name: 'Near',
        nameBn: 'কাছের',
        lat: 0.01,
        lon: 0.01,
        capacity: 500,
        source: 'test'),
    const Shelter(
        name: 'Mid',
        nameBn: 'মাঝারি',
        lat: 0.1,
        lon: 0.1,
        capacity: 800,
        source: 'test'),
  ];

  group('ShelterToolDispatcher.dispatch', () {
    test('returns the N nearest shelters sorted by distance', () {
      final result = ShelterToolDispatcher.dispatch(
        args: const {'count': 2},
        userLat: 0.0,
        userLon: 0.0,
        shelters: shelters,
      );
      expect(result.length, 2);
      // 'Near' (0.01, 0.01) must come before 'Mid' (0.1, 0.1).
      expect(result.first.shelter.name, 'Near');
      expect(result.last.shelter.name, 'Mid');
      // Distances must be ascending.
      expect(result[0].km, lessThan(result[1].km));
    });

    test('defaults to 3 when count is missing', () {
      final result = ShelterToolDispatcher.dispatch(
        args: const {},
        userLat: 0.0,
        userLon: 0.0,
        shelters: shelters,
      );
      expect(result.length, 3);
    });

    test('clamps count to the number of available shelters', () {
      final result = ShelterToolDispatcher.dispatch(
        args: const {'count': 99},
        userLat: 0.0,
        userLon: 0.0,
        shelters: shelters,
      );
      expect(result.length, 3);
    });

    test('coerces non-integer count gracefully', () {
      final result = ShelterToolDispatcher.dispatch(
        args: const {'count': 'oops'},
        userLat: 0.0,
        userLon: 0.0,
        shelters: shelters,
      );
      expect(result.length, 3,
          reason: 'A garbage count falls back to the default of 3.');
    });

    test('returns empty list when no shelters are available', () {
      final result = ShelterToolDispatcher.dispatch(
        args: const {'count': 5},
        userLat: 0.0,
        userLon: 0.0,
        shelters: const [],
      );
      expect(result, isEmpty);
    });
  });

  group('ShelterToolDispatcher.extractArgsFromJson', () {
    test('parses a well-formed tool-call JSON envelope', () {
      // The shape flutter_gemma emits when the model calls a tool:
      // either {"name": "find_nearest_shelter", "arguments": {...}}
      // or nested under tool_calls.
      const json = {
        'name': 'find_nearest_shelter',
        'arguments': {'count': 2},
      };
      final args = ShelterToolDispatcher.extractArgsFromJson(json);
      expect(args, isNotNull);
      expect(args!['count'], 2);
    });

    test('parses the tool_calls[] array envelope', () {
      const json = {
        'tool_calls': [
          {
            'function': {
              'name': 'find_nearest_shelter',
              'arguments': {'count': 1},
            }
          }
        ]
      };
      final args = ShelterToolDispatcher.extractArgsFromJson(json);
      expect(args, isNotNull);
      expect(args!['count'], 1);
    });

    test('returns null when the JSON is for a different tool', () {
      const json = {
        'name': 'submit_sos_report',
        'arguments': {'location': 'Dhaka'},
      };
      final args = ShelterToolDispatcher.extractArgsFromJson(json);
      expect(args, isNull);
    });

    test('returns null when no tool call is present', () {
      const json = {'content': 'just a normal reply'};
      final args = ShelterToolDispatcher.extractArgsFromJson(json);
      expect(args, isNull);
    });
  });

  group('ShelterToolDispatcher.isShelterToolCall', () {
    test('true for the shelter tool name', () {
      expect(
        ShelterToolDispatcher.isShelterToolCall(
          {'name': 'find_nearest_shelter'},
        ),
        isTrue,
      );
    });

    test('false for other tool names', () {
      expect(
        ShelterToolDispatcher.isShelterToolCall(
          {'name': 'submit_sos_report'},
        ),
        isFalse,
      );
    });

    test('false for plain content', () {
      expect(
        ShelterToolDispatcher.isShelterToolCall({'content': 'hi'}),
        isFalse,
      );
    });
  });
}
