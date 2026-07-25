import 'package:flutter/foundation.dart';

import '../../core/model_manager.dart';

/// A single data point for the situation summary.
class SituationReport {
  final String query;
  final String source; // 'chat' | 'sos' | 'manual'
  final DateTime when;

  const SituationReport({
    required this.query,
    required this.source,
    required this.when,
  });

  /// Convenience for fresh reports.
  factory SituationReport.now({
    required String query,
    required String source,
  }) =>
      SituationReport(query: query, source: source, when: DateTime.now());
}

/// Build the summarization prompt. Returns null if [reports] is empty.
String? buildSituationPrompt(List<SituationReport> reports) {
  if (reports.isEmpty) return null;
  final buf = StringBuffer();
  buf.writeln('তুমি শঙ্গজগ। নিচের সাম্প্রতিক প্রতিবেদনগুলির ভিত্তিতে '
      'বর্তমান পরিস্থিতির একটি সংক্ষিপ্ত সারাংশ বাংলায় দাও।');
  buf.writeln();
  buf.writeln('• সবচেয়ে সাধারণ ঘটনা');
  buf.writeln('• সর্বোচ্চ অগ্রাধিকার এলাকা');
  buf.writeln('• প্রস্তাবিত পদক্ষেপ');
  buf.writeln();
  buf.writeln('প্রতিবেদন (${reports.length} টি):');
  for (final r in reports) {
    buf.writeln('• [${r.source}] ${r.query}');
  }
  buf.writeln();
  buf.write('সারাংশ:');
  return buf.toString();
}

/// Deterministic fallback summary that aggregates incident counts.
String fallbackSituationSummary(List<SituationReport> reports) {
  if (reports.isEmpty) {
    return 'এই মুহূর্তে কোনো সক্রিয় প্রতিবেদন নেই। পরিস্থিতি স্বাভাবিক।';
  }
  final sosCount = reports.where((r) => r.source == 'sos').length;
  final chatCount = reports.length - sosCount;
  final totalBn = _bn(reports.length);
  final buf = StringBuffer();
  buf.writeln('পরিস্থিতির সারাংশ:');
  buf.writeln();
  buf.writeln('• মোট প্রতিবেদন: $totalBn টি');
  if (sosCount > 0) {
    buf.writeln('• SOS রিপোর্ট: ${_bn(sosCount)} টি');
  }
  if (chatCount > 0) {
    buf.writeln('• AI সহায়িকা প্রশ্ন: ${_bn(chatCount)} টি');
  }
  buf.writeln();
  if (sosCount > 0) {
    buf.writeln('সর্বোচ্চ অগ্রাধিকার: SOS রিপোর্টগুলি — ৯৯৯ এ যোগাযোগ করুন।');
  } else {
    buf.writeln('বর্তমান পরিস্থিতি সাধারণ। সাহায্যের জন্য AI সহায়িকা ব্যবহার করুন।');
  }
  return buf.toString();
}

/// Generate a summary via the on-device model; fall back to the
/// deterministic summary on any failure. The UI never sees empty.
Future<String> generateSituationSummary(
    List<SituationReport> reports) async {
  if (reports.isEmpty) {
    return fallbackSituationSummary(const []);
  }

  final prompt = buildSituationPrompt(reports);
  try {
    final shouldTryDevice =
        modelManager.isReady || await modelManager.isAnyOnDisk();
    if (shouldTryDevice && prompt != null) {
      final raw = await modelManager.generate(prompt);
      final cleaned = _clean(raw);
      if (cleaned.isNotEmpty) return cleaned;
    }
  } catch (e) {
    debugPrint('[SituationSummary] model failed, using fallback: $e');
  }
  return fallbackSituationSummary(reports);
}

String _clean(String raw) {
  var s = raw;
  s = s.replaceAll(
      RegExp(r'<\|channel\|>thinking.*?(?=<\|channel\|>final|$)',
          dotAll: true),
      '');
  s = s.replaceAll(RegExp(r'<\|[^|]*\|>'), '');
  return s.trim();
}

String _bn(int n) => n.toString().split('').map((c) {
      const m = {
        '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
        '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
      };
      return m[c] ?? c;
    }).join();