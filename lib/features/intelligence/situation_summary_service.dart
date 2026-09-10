import 'package:flutter/foundation.dart';

import 'situation_summary_strings_loader.dart';

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
String? buildSituationPrompt(
  List<SituationReport> reports, {
  SituationSummaryStrings? s,
}) {
  final strings = s ?? cachedSituationSummary;
  if (reports.isEmpty) return null;
  final buf = StringBuffer();
  buf.writeln(strings.systemRole);
  buf.writeln();
  buf.writeln(strings.bulletCommon);
  buf.writeln(strings.bulletPriority);
  buf.writeln(strings.bulletAction);
  buf.writeln();
  buf.writeln(strings.reportHeader.replaceAll('{count}', '${reports.length}'));
  for (final r in reports) {
    buf.writeln(strings.reportEntry
        .replaceAll('{source}', r.source)
        .replaceAll('{query}', r.query));
  }
  buf.writeln();
  buf.write(strings.summaryLabel);
  return buf.toString();
}

/// Deterministic fallback summary that aggregates incident counts.
String fallbackSituationSummary(
  List<SituationReport> reports, {
  SituationSummaryStrings? s,
}) {
  final strings = s ?? cachedSituationSummary;
  if (reports.isEmpty) {
    return strings.fallbackEmpty;
  }
  final sosCount = reports.where((r) => r.source == 'sos').length;
  final chatCount = reports.length - sosCount;
  final buf = StringBuffer();
  buf.writeln(strings.fallbackTitle);
  buf.writeln();
  buf.writeln(strings.fallbackTotal.replaceAll('{count}', _bn(reports.length)));
  if (sosCount > 0) {
    buf.writeln(strings.fallbackSos.replaceAll('{count}', _bn(sosCount)));
  }
  if (chatCount > 0) {
    buf.writeln(strings.fallbackChat.replaceAll('{count}', _bn(chatCount)));
  }
  buf.writeln();
  if (sosCount > 0) {
    buf.writeln(strings.fallbackSosPriority);
  } else {
    buf.writeln(strings.fallbackRoutine);
  }
  return buf.toString();
}

/// Generate a summary via the on-device model; fall back to the
/// deterministic summary on any failure. The UI never sees empty.
Future<String> generateSituationSummary(
  List<SituationReport> reports, {
  SituationSummaryStrings? s,
}) async {
  final strings = s ?? cachedSituationSummary;
  if (reports.isEmpty) {
    return fallbackSituationSummary(const [], s: strings);
  }

  buildSituationPrompt(reports, s: strings);
  debugPrint('[SitSummary] entered with ${reports.length} reports');
  // For now we use the deterministic fallback as the model path
  // isn't wired into this service in the current build.
  final summary = fallbackSituationSummary(reports, s: strings);
  debugPrint('[SitSummary] generated len=${summary.length}');
  return summary;
  // prompt is intentionally built but unused here — kept for the future
  // model-driven path.
  // ignore: dead_code
  // ignore: unused_local_variable
  // final _ = prompt;
}

/// Convert int to Bengali digits string.
String _bn(int n) => n.toString().split('').map((c) {
      const m = {
        '0': '০', '1': '১', '2': '২', '3': '৩', '4': '৪',
        '5': '৫', '6': '৬', '7': '৭', '8': '৮', '9': '৯',
      };
      return m[c] ?? c;
    }).join();
