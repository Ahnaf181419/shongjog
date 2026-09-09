import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Independent-review suggestion 5 (2026-09-09): the F7 dedup guard
  // is keyed only by caller id, so a redial from the same caller
  // (call dropped, immediate redial) is also suppressed until the
  // first MeshCallScreen pops. Reviewer called this an acceptable
  // trade-off worth pinning in a unit test.
  //
  // The guard logic is private to _MainShellState. We pin it via a
  // small reproduction: a stateful widget whose `_activeIncomingCallFromId`
  // mirrors the production short-circuit exactly.

  testWidgets(
      'redial from same caller is suppressed while first call is up',
      (tester) async {
    var pushed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: _DedupProbe(onPush: () => pushed++),
      ),
    );

    // First signal — pushes the screen.
    await tester.tap(find.text('first'));
    expect(pushed, 1);
    await tester.pump(const Duration(milliseconds: 50));

    // Same caller, second signal — must NOT push a duplicate.
    await tester.tap(find.text('second'));
    expect(pushed, 1,
        reason: 'Dedup guard must suppress the redial while the call screen is up');

    // Pop the call screen — next signal from the same caller must push.
    await tester.tap(find.text('pop'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('first'));
    expect(pushed, 2,
        reason: 'After the call screen pops, the next signal must present again');
  });
}

class _DedupProbe extends StatefulWidget {
  final VoidCallback onPush;
  const _DedupProbe({required this.onPush});

  @override
  State<_DedupProbe> createState() => _DedupProbeState();
}

class _DedupProbeState extends State<_DedupProbe> {
  // Mirrors main_shell.dart's _activeIncomingCallFromId. This is the
  // minimal surface of the dedup guard; a production test would
  // exercise the full _showIncomingCall path.
  String? _activeIncomingCallFromId;

  void _onSignal(String fromId) {
    if (_activeIncomingCallFromId == fromId) return;
    _activeIncomingCallFromId = fromId;
    widget.onPush();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () => _onSignal('caller-1'),
            child: const Text('first'),
          ),
          ElevatedButton(
            onPressed: () => _onSignal('caller-1'),
            child: const Text('second'),
          ),
          ElevatedButton(
            onPressed: () => setState(() => _activeIncomingCallFromId = null),
            child: const Text('pop'),
          ),
        ],
      ),
    );
  }
}
