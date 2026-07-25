import 'package:flutter_gemma/core/tool.dart';

/// The shelter-search tool definition — passed to
/// `createSession(tools: [findNearestShelterTool])`.
///
/// The model fills these fields from the user's natural-language
/// location request ("I'm in Patuakhali, which shelter is closest?").
/// The caller parses the function-call response and runs the pure-Dart
/// `ShelterToolDispatcher.dispatch` to get real ranked shelters.
///
/// Mirrors the proven pattern from `sos_function_schema.dart`.
const Tool findNearestShelterTool = Tool(
  name: 'find_nearest_shelter',
  description: '''
Find the nearest cyclone shelters to the user's location. Use this when
the user asks where to go during a cyclone, flood, or emergency, or
asks for the closest shelter. Returns ranked shelters with distance.
''',
  parameters: {
    'type': 'object',
    'properties': {
      'count': {
        'type': 'integer',
        'description': 'Number of shelters to return (default 3, max 10)',
      },
    },
  },
);
