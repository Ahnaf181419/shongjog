import 'package:shongjog/features/triage/triage_tts.dart';

/// Test seam — counts every speak() call. Used by the triage widget
/// tests to verify that auto-read is wired correctly. Lives under
/// `test/widget/` so both unit and widget tests can import it.
class FakeTriageTts implements TriageTts {
  final List<String> spoken = [];
  bool stopped = false;

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}
