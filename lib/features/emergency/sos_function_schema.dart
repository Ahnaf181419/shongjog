/// Structured SOS function-calling schema.
///
/// Defines the tool that Gemma uses to extract structured emergency
/// dispatch info from panicked voice/text input. The model's response
/// is formatted for a 999 operator and sent as SMS (which survives when
/// data doesn't).
library;

import 'package:flutter_gemma/core/tool.dart';

/// The SOS report tool definition — passed to `createSession(tools: [...])`.
///
/// The model fills these fields from the user's panicked description.
/// The caller then parses the function-call response and builds the SMS body.
const Tool sosReportTool = Tool(
  name: 'submit_sos_report',
  description: '''
Submit a structured emergency dispatch report from the caller's description.
Extract: location, hazard type, number of casualties, injuries, immediate needs,
and access notes. All fields are optional — fill what you can infer.
''',
  parameters: {
    'type': 'object',
    'properties': {
      'location': {
        'type': 'string',
        'description': 'Location or area name (Bangla)',
      },
      'hazard_type': {
        'type': 'string',
        'description': 'Type of emergency: বন্যা, অগ্নিকাণ্ড, সাপ, ডুবে যাওয়া, আহত, গর্ভবতী, অন্যান্য',
      },
      'casualty_count': {
        'type': 'integer',
        'description': 'Number of people affected',
      },
      'injuries': {
        'type': 'string',
        'description': 'Description of injuries or symptoms (Bangla)',
      },
      'immediate_needs': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'What help is needed: অ্যাম্বুলেন্স, উদ্ধার, চিকিৎসা, খাবার, পানি',
      },
      'access_notes': {
        'type': 'string',
        'description': 'Road access, landmarks, or obstacles for responders (Bangla)',
      },
    },
  },
);

/// Builds the SOS SMS body from the structured fields.
///
/// Format is optimized for 999 operators: compact, scannable, Bangla.
String buildSosSmsBody(Map<String, dynamic> fields) {
  final buf = StringBuffer()..writeln('শঙ্গজগ SOS রিপোর্ট:');
  buf.writeln();

  if (fields['location'] != null) {
    buf.writeln('স্থান: ${fields['location']}');
  }
  if (fields['hazard_type'] != null) {
    buf.writeln('ধরন: ${fields['hazard_type']}');
  }
  if (fields['casualty_count'] != null) {
    buf.writeln('আহত/ক্ষতিগ্রস্ত: ${fields['casualty_count']} জন');
  }
  if (fields['injuries'] != null) {
    buf.writeln('আঘাত: ${fields['injuries']}');
  }
  if (fields['immediate_needs'] != null) {
    final needs = fields['immediate_needs'] as List;
    if (needs.isNotEmpty) {
      buf.writeln('প্রয়োজন: ${needs.join(', ')}');
    }
  }
  if (fields['access_notes'] != null) {
    buf.writeln('প্রবেশপথ: ${fields['access_notes']}');
  }

  buf.writeln();
  buf.write('— শঙ্গজগ অ্যাপ থেকে পাঠানো');

  return buf.toString();
}
