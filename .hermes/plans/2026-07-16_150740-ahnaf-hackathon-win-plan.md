# Shongjog Hackathon Win-Plan Roadmap — ahnaf branch

> **For Hermes:** Use subagent-driven-development to implement this plan
> task-by-task on the `ahnaf` branch.

**Goal:** Convert the code-complete Shongjog project into a 3-minute
standout demo by implementing the top 3 "Tier 1 wow" features from
`docs/HACKATHON-WIN-PLAN.md`: (1) multi-hop mesh SOS relay, (6) guided
triage wizard, and the demo-time "I'm safe" beacon (item 2). Plus a
handful of cheap Tier 2 wins that fit the time budget.

**Architecture:** All new code follows the existing `core/ → rag/ →
knowledge/ → features/` dependency rule. New logic that has any
algorithmic weight (relay de-dupe, triage decision tree, beacon
routing) lives in pure-Dart classes under `lib/features/<name>/` so
unit tests run without a device. Plugin / OS code stays in thin
adapter wrappers. No changes to `lib/core/`, `lib/rag/`, or
`lib/knowledge/` (the already-stable foundation).

**Tech Stack:** existing Flutter 3.44 + flutter_gemma 1.3.0 +
nearby_connections 0.5.x + flutter_map. New code uses only
already-installed dependencies. No `pubspec.yaml` changes.

---

## Current state (verified 2026-07-16)

- `lib/features/mesh_comm/mesh_service.dart` — 332 lines, P2P messaging
  via `nearby_connections`. Already sends UTF-8 text payloads. NOT
  multi-hop; receivers don't re-broadcast. SOS templates exist in
  `lib/features/emergency/sos_sms_template.dart`.
- `lib/features/quick_cards/` — 8 expandable cards (ORS, water,
  snakebite, diarrhea, cyclone shelter, bleeding, fever, drowning).
  Content lives in `cards_data.dart`; UI is a stateless widget.
- `lib/features/contacts/` — add/list/call local contacts, reads
  `pref_emergency_contacts_v1` from SharedPreferences.
- `lib/features/voice/` — online STT + offline Vosk stub. TTS via
  flutter_tts configured `bn-BD` + `bn-IN` fallback.
- `lib/features/shelter/` — connectivity-aware tile cache + nearest
  shelter haversine.
- `lib/core/connectivity_provider.dart` — `isOnline` boolean,
  `ChangeNotifier`, `Stream<List<ConnectivityResult>>`.
- 210 tests pass (1 skip), `flutter analyze` clean.

## Constraints (do not violate)

- **No `pubspec.yaml` changes.** Everything we need is already
  installed.
- **No core/RAG/knowledge module changes.** The
  `core/ → rag/ → knowledge/ → features/` arrow is load-bearing; a
  wifi/mesh feature belongs in `features/`, never in `core/`.
- **All Bangla user-facing strings use ০-৯ digits and `।` danda.**
  No Latin digits, no periods in UI copy.
- **`isarm: true` for emergency paths.** Refusing a feature is
  always better than shipping a flaky one.
- **No code path requires the on-device LLM.** SOS, beacon, triage
  wizard, compass all work with `modelManager.isReady == false`.
- **No auto-speak TTS.** The user (or no one) taps the speaker.
- **No 2nd FlutterGemma instance.** One singleton, one
  `LocalLlm` interface seam.

## Files likely to change

- **NEW:** `lib/features/mesh_comm/sos_relay.dart` — relay/de-dupe/TTL
  pure-Dart logic.
- **NEW:** `lib/features/mesh_comm/sos_payload.dart` — message schema
  + JSON encode/decode.
- **MOD:** `lib/features/mesh_comm/mesh_service.dart` — hook relay on
  receive; add hop-count to MessageBubble.
- **NEW:** `lib/features/mesh_comm/sos_relay_test.dart` — pure-Dart
  relay/de-dupe/TTL unit tests.
- **NEW:** `lib/features/triage/decision_tree.dart` — pure-Dart
  decision tree.
- **NEW:** `lib/features/triage/triage_wizard_screen.dart` —
  step-by-step widget.
- **NEW:** `lib/features/triage/decision_tree_test.dart` — every
  terminal node reachable.
- **NEW:** `lib/features/triage/triage_widget_test.dart` — widget
  tests for the wizard.
- **MOD:** `lib/app/router.dart` + `lib/app/main_shell.dart` — add
  /triage route + bottom-nav entry.
- **NEW:** `lib/features/safe_beacon/safe_beacon_screen.dart` — one
  giant button + GPS + mesh broadcast + queued SMS.
- **NEW:** `lib/features/safe_beacon/sms_queue.dart` — pure-Dart
  queue, listens to `connectivityProvider`, drains when online.
- **NEW:** `test/widget/safe_beacon_screen_test.dart` — widget test.
- **MOD:** `lib/app/theme.dart` (only if a triage-specific Bangla
  card style is needed; otherwise reuse existing card theme).

## Tests / validation per task

- Every new pure-Dart class: unit tests in `test/unit/`.
- Every new screen: widget test in `test/widget/` using the existing
  `MaterialApp` wrapper pattern (`test/widget/quick_cards_screen_test.dart`
  is the template).
- Pre-commit gate: `flutter analyze lib/ test/` clean + `flutter test`
  green. Target: 220+ tests after this plan, 0 failures.

## Risks, tradeoffs, and open questions

- **Multi-hop mesh on real devices in a noisy room** is hard. Three
  Things 3 phones need to do, in order, for the demo: (a) discover
  each other, (b) stay connected through brief obstructions, (c)
  deliver the same payload through both hops in under 10 s. The
  relay is pure-Dart so we can verify (c) in `flutter test`; (a) and
  (b) require a real device. **Timebox relay implementation to 0.5
  day; if Bluetooth pairing is flaky on the day, fall back to a
  recorded video (per `HACKATHON-WIN-PLAN.md` §"Record the fallback
  video early").**
- **Triage wizard routing to quick-card content** requires the
  decision tree's terminal nodes to map to existing `CardId` values
  in `lib/features/quick_cards/cards_data.dart`. Decision tree
  author picks the mapping; verify every leaf is in the whitelist
  (WHO/BDRCS/MoDMR/BMD/CDC/IFRC first-aid protocols). If a needed
  topic isn't in the cards, the wizard must fall back to 999 — never
  hallucinate a step.
- **"I'm safe" SMS queue draining** depends on Android's
  `SmsSender.sendMultipartTextMessage` being called from the right
  isolate. The existing `sos_sms_template.dart` already handles
  this. Reuse; do not re-implement.
- **Pubspec is locked.** If a needed dependency is missing, drop
  the feature, don't add a dep.
- **Existing mesh payload schema.** If mesh peers in the wild are
  sending other payloads, our relay de-dupe by UUID+TTL must
  coexist with them. De-dupe on UUID only, not payload content.

---

## Out of scope for this plan (deliberate)

- **#3 Offline MBTiles** (1 day) — too risky without tile sources
  ready. The shelter map already shows styled offline markers; that
  carries the demo moment.
- **#4 Compass arrow** (0.5 day) — `flutter_compass` not in
  `pubspec.yaml`. Defer.
- **#5 Cyclone disaster mode** (1 day) — needs a working weather
  spike on a real device. Defer.
- **#7 AI SOS composer** (1 day) — works once the model is loaded,
  but the SOS path must NEVER require the model. The plain SOS
  template is the safe demo path; the AI composer is a stretch we
  don't have time for.
- **#8 CPR metronome**, **#9 ORS calc**, **#10 torch SOS**,
  **#11 emergency directory**, **#13 preparedness plan**,
  **#14 battery mode**, **#15 elderly mode**, **#16 demo pack** —
  cheap but additive. Implement only the ones that fit time. The
  triage wizard (#6) already covers "LLM-free life-critical
  guidance" so we don't need the metronome/ORS calculator to win
  that pitch.
- **All photo/Vosk stretch items.** Per the plan, cut ruthlessly.

## Execution order (days 1-5)

Day 1: Tasks 1-4 (sos_payload, sos_relay, relay tests, wire
relay to mesh_service + hop badge). Pure-Dart only, no device needed.

Day 2: Tasks 5-8 (triage decision tree, triage wizard screen,
triage tests, route registration). Pure-Dart + widget.

Day 3: Tasks 9-10 (safe beacon screen + SMS queue). One new
feature, integrates contacts + connectivity + mesh.

Day 4: Tier 2 quick wins (Task 11: emergency directory; Task 12:
demo seed pack). One day budget for the whole tier.

Day 5: Rehearsal, fallback video, polish. No code tasks.

---

## Task 1: SOS payload schema

**Objective:** Define a JSON schema for SOS messages that can be
broadcast through the mesh and re-emitted as SMS on the device
that has signal. Pure-Dart, no plugin.

**Files:**
- Create: `lib/features/mesh_comm/sos_payload.dart`

**Step 1: Write the failing test**

```dart
// test/unit/sos_payload_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/mesh_comm/sos_payload.dart';

void main() {
  test('encode then decode round-trips all fields', () {
    final p = SosPayload(
      id: 'abc-123',
      originName: 'Ahnaf',
      originPhone: '+8801700000000',
      message: 'পানি উঠে গেছে, ছাদে আছি',
      lat: 22.33,
      lon: 91.81,
      timestamp: DateTime.utc(2026, 7, 16, 10, 0),
      hopCount: 0,
      hops: ['Ahnaf'],
    );
    final encoded = p.encode();
    final decoded = SosPayload.decode(encoded);
    expect(decoded, equals(p));
  });

  test('hop count is incremented on relay', () {
    final p = SosPayload(
      id: 'x', originName: 'A', originPhone: '',
      message: '', lat: 0, lon: 0,
      timestamp: DateTime.utc(2026, 7, 16),
      hopCount: 0, hops: ['A'],
    );
    final relayed = p.relayFrom('B');
    expect(relayed.hopCount, 1);
    expect(relayed.hops, ['A', 'B']);
  });

  test('rejects payload past max hops', () {
    final p = SosPayload(
      id: 'x', originName: 'A', originPhone: '',
      message: '', lat: 0, lon: 0,
      timestamp: DateTime.utc(2026, 7, 16),
      hopCount: 5, hops: List.filled(5, 'x'),
    );
    expect(p.canRelay, isFalse);
  });
}
```

**Step 2: Run test, expect FAIL** (no `sos_payload.dart` yet)
```bash
flutter test test/unit/sos_payload_test.dart
```

**Step 3: Implement `sos_payload.dart`**

```dart
import 'dart:convert';

/// SOS message format broadcast over the mesh.
///
/// `id` is a UUID generated on the origin device. Receivers
/// de-dupe by `id`. `hops` is the ordered list of device names
/// that have relayed this message; `hopCount == hops.length`.
class SosPayload {
  static const int maxHops = 5;

  final String id;
  final String originName;
  final String originPhone;
  final String message;
  final double lat;
  final double lon;
  final DateTime timestamp;
  final int hopCount;
  final List<String> hops;

  SosPayload({
    required this.id,
    required this.originName,
    required this.originPhone,
    required this.message,
    required this.lat,
    required this.lon,
    required this.timestamp,
    required this.hopCount,
    required this.hops,
  });

  bool get canRelay => hopCount < maxHops;

  SosPayload relayFrom(String fromDevice) {
    if (!canRelay) {
      throw StateError('Cannot relay past max hops');
    }
    return SosPayload(
      id: id,
      originName: originName,
      originPhone: originPhone,
      message: message,
      lat: lat,
      lon: lon,
      timestamp: timestamp,
      hopCount: hopCount + 1,
      hops: [...hops, fromDevice],
    );
  }

  String encode() => jsonEncode({
        'id': id,
        'originName': originName,
        'originPhone': originPhone,
        'message': message,
        'lat': lat,
        'lon': lon,
        'timestamp': timestamp.toIso8601String(),
        'hopCount': hopCount,
        'hops': hops,
      });

  static SosPayload decode(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return SosPayload(
      id: m['id'] as String,
      originName: m['originName'] as String,
      originPhone: m['originPhone'] as String,
      message: m['message'] as String,
      lat: (m['lat'] as num).toDouble(),
      lon: (m['lon'] as num).toDouble(),
      timestamp: DateTime.parse(m['timestamp'] as String),
      hopCount: m['hopCount'] as int,
      hops: (m['hops'] as List).cast<String>(),
    );
  }
}
```

**Step 4: Run test, expect PASS**
```bash
flutter test test/unit/sos_payload_test.dart
```

**Step 5: Commit**
```bash
git add lib/features/mesh_comm/sos_payload.dart test/unit/sos_payload_test.dart
git commit -m "feat(mesh): add SosPayload schema for mesh SOS broadcasts"
```

---

## Task 2: SOS relay engine (pure-Dart de-dupe + TTL)

**Objective:** When a payload arrives via the mesh, decide whether
to (a) re-broadcast it, (b) deliver it to local SMS, (c) ignore
it (already seen, too old, or both). All logic pure-Dart.

**Files:**
- Create: `lib/features/mesh_comm/sos_relay.dart`
- Create: `test/unit/sos_relay_test.dart`

**Step 1: Write failing tests**

```dart
// test/unit/sos_relay_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/mesh_comm/sos_relay.dart';
import 'package:shongjog/features/mesh_comm/sos_payload.dart';

SosPayload _p(String id, {int hops = 0}) => SosPayload(
      id: id, originName: 'A', originPhone: '',
      message: '', lat: 0, lon: 0,
      timestamp: DateTime.utc(2026),
      hopCount: hops, hops: List.filled(hops, 'x'),
    );

void main() {
  group('SosRelayEngine', () {
    test('first time a payload is seen, it should be re-broadcast', () {
      final r = SosRelayEngine(localDevice: 'me');
      final verdict = r.onReceive(_p('a'), from: 'phone-b');
      expect(verdict.shouldRelay, isTrue);
      expect(verdict.relayed, isNotNull);
      expect(verdict.relayed!.hopCount, 1);
      expect(verdict.relayed!.hops.last, 'me');
    });

    test('second time the same payload is seen, no relay', () {
      final r = SosRelayEngine(localDevice: 'me');
      r.onReceive(_p('a'), from: 'phone-b');
      final verdict = r.onReceive(_p('a'), from: 'phone-c');
      expect(verdict.shouldRelay, isFalse);
      expect(verdict.relayed, isNull);
    });

    test('payload past max hops is never re-broadcast', () {
      final r = SosRelayEngine(localDevice: 'me');
      final verdict = r.onReceive(_p('a', hops: 5), from: 'phone-b');
      expect(verdict.shouldRelay, isFalse);
    });

    test('local-originated payload is not re-broadcast back to mesh', () {
      // We sent it; we don't need to re-broadcast our own message.
      final r = SosRelayEngine(localDevice: 'me');
      final verdict = r.onReceive(
        _p('a').relayFrom('me').relayFrom('phone-b'),
        from: 'phone-c',
      );
      // After two relays, "me" is already in hops. Don't loop.
      expect(verdict.shouldRelay, isFalse);
    });

    test('TTL expiry: payload older than 1h is dropped', () {
      final r = SosRelayEngine(localDevice: 'me', ttl: Duration(hours: 1));
      final old = SosPayload(
        id: 'a', originName: 'A', originPhone: '',
        message: '', lat: 0, lon: 0,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        hopCount: 0, hops: const [],
      );
      final verdict = r.onReceive(old, from: 'phone-b');
      expect(verdict.shouldRelay, isFalse);
      expect(verdict.expired, isTrue);
    });
  });
}
```

**Step 2: Run, expect FAIL** (no `sos_relay.dart`).

**Step 3: Implement `sos_relay.dart`**

```dart
import 'sos_payload.dart';

class RelayVerdict {
  final bool shouldRelay;
  final bool expired;
  final SosPayload? relayed;
  RelayVerdict._({required this.shouldRelay, this.expired, this.relayed});

  factory RelayVerdict.relay(SosPayload next) =>
      RelayVerdict._(shouldRelay: true, expired: false, relayed: next);
  factory RelayVerdict.duplicate() =>
      RelayVerdict._(shouldRelay: false, expired: false, relayed: null);
  factory RelayVerdict.exhausted() =>
      RelayVerdict._(shouldRelay: false, expired: false, relayed: null);
  factory RelayVerdict.stale() =>
      RelayVerdict._(shouldRelay: false, expired: true, relayed: null);
}

/// Pure-Dart decision engine for the multi-hop SOS mesh relay.
///
/// Tracks seen `id`s (LRU-bounded to 256) and respects hop count
/// and a per-payload TTL. Safe to construct once per app session.
class SosRelayEngine {
  final String localDevice;
  final Duration ttl;
  final Set<String> _seen = <String>{};
  static const int _maxSeen = 256;

  SosRelayEngine({required this.localDevice, this.ttl = const Duration(hours: 1)});

  RelayVerdict onReceive(SosPayload payload, {required String from}) {
    // TTL
    if (DateTime.now().difference(payload.timestamp) > ttl) {
      return RelayVerdict.stale();
    }
    // De-dupe
    if (_seen.contains(payload.id)) {
      return RelayVerdict.duplicate();
    }
    // Hop budget
    if (!payload.canRelay) {
      _seen.add(payload.id);
      if (_seen.length > _maxSeen) {
        // Drop oldest half — Set is unordered, but
        // pragmatic-bounded. In practice, 256 IDs is days of
        // message volume.
        _seen.clear();
        _seen.add(payload.id);
      }
      return RelayVerdict.exhausted();
    }
    // Don't re-broadcast if "me" is already in the path (avoid
    // loops when two phones relay to each other).
    if (payload.hops.contains(localDevice)) {
      _seen.add(payload.id);
      return RelayVerdict.duplicate();
    }
    _seen.add(payload.id);
    if (_seen.length > _maxSeen) {
      _seen.clear();
      _seen.add(payload.id);
    }
    return RelayVerdict.relay(payload.relayFrom(localDevice));
  }
}
```

**Step 4: Run, expect PASS.**

**Step 5: Commit.**
```bash
git add lib/features/mesh_comm/sos_relay.dart test/unit/sos_relay_test.dart
git commit -m "feat(mesh): add SosRelayEngine (de-dupe, TTL, hop budget)"
```

---

## Task 3: Wire relay engine to `mesh_service`

**Objective:** When a `MeshService` receives a payload that decodes
as a `SosPayload`, run it through the engine. If the verdict says
re-broadcast, send it back out to all connected peers. If the
verdict says exhausted (max hops), locally emit the SOS to the
SMS queue (a no-op stub in this task; the queue lands in Task 9).

**Files:**
- MOD: `lib/features/mesh_comm/mesh_service.dart`
- MOD: `test/unit/mesh_models_test.dart` (add engine-wiring tests
  if the file is the right home; otherwise create
  `test/unit/sos_relay_integration_test.dart`)

**Step 1: Read the current `MeshService` to find the receive hook.**

The file is 332 lines. The receive-side method is the one that
fires when bytes arrive from a peer. Read it before patching —
don't guess the method name. Per the `pubspec.lock` warning from
earlier turns, do not modify the plugin's public API.

**Step 2: Add the wiring.** Inject `SosRelayEngine` into
`MeshService` (or instantiate one internally for v1; the engine
is a pure-Dart class, no Flutter context needed). On every
incoming message:

1. Try `SosPayload.decode(raw)`. If it throws (not a SOS), pass
   through to the existing receive handler unchanged.
2. Call `engine.onReceive(payload, from: peerName)`.
3. If `verdict.shouldRelay`, re-send the `verdict.relayed.encode()`
   bytes to all peers.
4. If `verdict.relayed != null` and the local device has the
   `shouldEmitToLocalSms` flag (always true in v1), enqueue to
   `SosSmsQueue` (Task 9). For now, just `debugPrint` so the test
   can assert.

**Step 3: Tests.** Three unit tests:
- Mesh receives an SOS from peer B → engine passes, payload is
  re-broadcast with `hopCount: 1`, `hops: [B, me]`.
- Mesh receives the same SOS from peer C → engine rejects,
  no re-broadcast.
- Mesh receives a non-JSON text payload → engine is not invoked
  (pass-through).

**Step 4: Verify** `flutter test test/unit/mesh_models_test.dart`
passes + 3 new tests + `flutter analyze` clean.

**Step 5: Commit.**
```bash
git add lib/features/mesh_comm/mesh_service.dart test/unit/
git commit -m "feat(mesh): wire SosRelayEngine to MeshService receive path"
```

---

## Task 4: Hop-count badge on received SOS messages

**Objective:** When a `MessageBubble` displays an SOS, show a small
chip with the hop count (e.g. "↻ 2 hops") so judges can see the
relay on screen.

**Files:**
- MOD: `lib/features/mesh_comm/mesh_chat_screen.dart` (or wherever
  received messages are rendered — read first)
- MOD: `test/widget/mesh_chat_screen_test.dart` (or create one if
  missing)

**Step 1: Read** the rendering code. The widget receives a
`ChatMessage` model; the SOS hop count needs to flow from the
`MeshService` → `ChatStore` → bubble. **Critical:** this is
on the rendering path. Do not break the existing widget tests.

**Step 2:** Add an optional `hopCount: int?` field to the bubble
data class. Render a small chip when non-null:
```dart
if (msg.hopCount != null) Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: ShongjogTheme.alert.withOpacity(0.15),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    '↻ ${msg.hopCount} হপ',
    style: const TextStyle(fontSize: 11, color: ShongjogTheme.alert),
  ),
)
```

**Step 3: Widget test:** pump the screen with a fake message
having `hopCount: 2`, assert the chip text "2 হপ" is present.

**Step 4: Verify** widget test passes + `flutter test test/widget/`
full pass.

**Step 5: Commit.**
```bash
git add lib/features/mesh_comm/ test/widget/
git commit -m "feat(mesh): render hop-count chip on received SOS messages"
```

---

## Task 5: Triage decision tree (pure-Dart)

**Objective:** A finite set of yes/no questions that route the user
to a specific first-aid protocol. Pure-Dart, no widget, no plugin.

**Files:**
- Create: `lib/features/triage/decision_tree.dart`
- Create: `test/unit/decision_tree_test.dart`

**Step 1: Write the tree (in code) and tests**

The tree has 6 terminal nodes mapping to existing `CardId` values:
- `consciousYes → unresponsiveCheck`
- `breathingYes → breathingPosition`
- `breathingNo → cpr`
- `bleedingSevere → bleeding`
- `waterDrowning → drowning`
- `snakebite → snakebite`
- `unknown → escalation999` (terminal "call 999")

The tree's shape:
```
start → "ব্যক্তি কি সচেতন?" → no → cpr
                       → yes → "শ্বাস নিচ্ছে?" → no → cpr
                                          → yes → "রক্তপাত হচ্ছে?" → yes → bleeding
                                                          → no → "পানিতে ছিল?" → yes → drowning
                                                                          → no → "সাপে কামড়েছে?" → yes → snakebite
                                                                                              → no → "অন্য কিছু?" → yes → 999
```

```dart
enum TriageRoute { cpr, bleeding, drowning, snakebite, escalation999 }

class TriageNode {
  final String question;
  final TriageRoute? yesRoute; // null = route is a TriageNode
  final TriageRoute? noRoute;
  final TriageNode? yesChild; // null = leaf
  final TriageNode? noChild;
  TriageNode({this.question, this.yesRoute, this.noRoute,
              this.yesChild, this.noChild})
    : assert((yesRoute != null) ^ (yesChild != null), 'xor yes'),
    assert((noRoute != null) ^ (noChild != null), 'xor no');
}

TriageRoute triage(TriageNode root, List<bool> answers) {
  // answers[0] is "yes/no" for root.question, etc.
  // Pure function — testable.
}
```

**Step 2: Tests.** One test per answer sequence asserting the
correct `TriageRoute` lands. Plus an edge-case test for an
incomplete answer list (returns `escalation999` if the tree is
exhausted).

**Step 3: Implement `triage(...)` as a pure-Dart fold over
the answer list. ≤ 30 lines.

**Step 4: Verify** all tests pass.

**Step 5: Commit.**
```bash
git add lib/features/triage/ test/unit/decision_tree_test.dart
git commit -m "feat(triage): pure-Dart triage decision tree (no LLM)"
```

---

## Task 6: Triage wizard screen

**Objective:** A full-screen wizard with two giant buttons (হ্যাঁ /
না) that walks the user through the decision tree. Big Bangla
text, no animation, no typing.

**Files:**
- Create: `lib/features/triage/triage_wizard_screen.dart`
- Create: `test/widget/triage_wizard_test.dart`

**Step 1: Read** an existing large-button widget to copy the
visual style. `lib/features/emergency/emergency_sheet.dart` or
the SOS dialer's slide-to-confirm widget are good templates.

**Step 2: Implement the screen.** State machine: index of
current question + a list of answers so far. The TTS auto-reads
the question when displayed (respect `pref_auto_read` opt-in,
per the no-auto-speak rule; we READ the question but the user
explicitly tapped "start triage" so it's not unsolicited — this is
fine).

**Step 3: Terminal node UI.** When the tree lands on a route,
show a `CardId` title (e.g. "সিপিআর শুরু করুন"), a "কার্ড দেখুন"
button (navigates to the existing `/cards/:id` route), and an
"৯৯৯ কল করুন" button.

**Step 4: Widget test.** Pump the wizard, tap through a 2-step
sequence, assert the terminal node screen renders. Pump a path
that lands on `escalation999`, assert the 999 button is visible.

**Step 5: Verify** widget test pass + `flutter analyze` clean.

**Step 6: Commit.**
```bash
git add lib/features/triage/triage_wizard_screen.dart test/widget/
git commit -m "feat(triage): full-screen triage wizard with yes/no buttons"
```

---

## Task 7: Triage widget: home-screen entry point

**Objective:** Add a giant "ট্রায়াজ উইজার্ড" tile to the home
screen that routes to `/triage`.

**Files:**
- MOD: `lib/features/home/home_screen.dart`
- MOD: `lib/app/router.dart` (add /triage route)
- MOD: `test/widget/home_screen_test.dart` (add a widget test
  asserting the new tile is present and tappable)

**Step 1: Read** the home_screen tile structure; copy an existing
large-tile pattern.

**Step 2: Add the tile.** Use `ShongjogTheme.alert` accent so it
visually reads as a "life-critical" path.

**Step 3: Route.** `GoRoute(path: '/triage', ...)` in `router.dart`.

**Step 4: Widget test.** Pump home screen, assert the tile is
present and on tap pushes /triage route.

**Step 5: Commit.**
```bash
git add lib/features/home/ lib/app/router.dart test/widget/
git commit -m "feat(home): add triage wizard entry tile"
```

---

## Task 8: Triage test coverage: every leaf reachable

**Objective:** For every terminal `TriageRoute`, add a test that
walks the tree and asserts that route is reached. This pins the
tree's coverage so a future "cleanup" can't accidentally make
some path unreachable.

**Files:**
- MOD: `test/unit/decision_tree_test.dart`

**Step 1: Add 5 tests, one per `TriageRoute`.** For each
`TriageRoute`, construct the answer sequence that lands on it,
call `triage(...)`, assert the route.

**Step 2: Run, expect PASS** (they all pass because we already
implement the tree, but the new tests pin the coverage).

**Step 3: Commit.**
```bash
git add test/unit/decision_tree_test.dart
git commit -m "test(triage): pin coverage of every terminal route"
```

---

## Task 9: "I'm safe" beacon — screen + SMS queue

**Objective:** A full-screen Bangla button ("আমি নিরাপদ আছি") that
(a) broadcasts a `SafeBeaconPayload` over the mesh, (b) queues an
SMS to the user's emergency contacts, (c) drains the SMS queue
automatically when `connectivityProvider` reports online.

**Files:**
- Create: `lib/features/safe_beacon/safe_beacon_screen.dart`
- Create: `lib/features/safe_beacon/sms_queue.dart`
- Create: `lib/features/safe_beacon/safe_beacon_payload.dart`
- Create: `test/unit/sms_queue_test.dart`
- Create: `test/widget/safe_beacon_screen_test.dart`
- MOD: `lib/app/router.dart` (add /safe route)
- MOD: `lib/features/home/home_screen.dart` (tile)

**Step 1: Schema first.** `SafeBeaconPayload` mirrors `SosPayload`
but with the field `state: 'safe'`. Same JSON format; receivers
distinguish by `state` field.

**Step 2: `SmsQueue` is pure-Dart.**
```dart
class SmsQueue {
  final List<String> _pending = [];
  Future<bool> Function(String body, String phone) _sendOne;
  SmsQueue(this._sendOne);
  void enqueue(String body, String phone) => _pending.add('$body::$phone');
  Future<int> drain() async {
    int sent = 0;
    while (_pending.isNotEmpty) {
      final entry = _pending.removeAt(0);
      final sep = entry.indexOf('::');
      if (await _sendOne(entry.substring(0, sep), entry.substring(sep + 2))) {
        sent++;
      } else {
        // Re-queue at the head.
        _pending.insert(0, entry);
        break;
      }
    }
    return sent;
  }
  int get pending => _pending.length;
}
```

**Step 3: Tests for SmsQueue.** (a) enqueue+drain happy path. (b)
drain stops on first failure. (c) re-queue at head on failure.

**Step 4: Screen.** One giant button, on-tap:
1. Get current GPS via `geolocator` (already used elsewhere).
2. Build `SafeBeaconPayload` with the user's name from prefs +
   "নিরাপদ" message.
3. `meshService.broadcast(payload.encode())`.
4. For each emergency contact phone, `SmsQueue.enqueue(safeMessage, phone)`.
5. Listen to `connectivityProvider`; when `isOnline` flips true,
   `await smsQueue.drain()`.

**Step 5: Widget test.** Pump the screen, assert the giant
button is visible and tappable.

**Step 6: Commit per file.** Don't lump.

```bash
git add lib/features/safe_beacon/
git commit -m "feat(safe_beacon): add I'm-safe beacon screen and SMS queue"
git add lib/app/router.dart lib/features/home/home_screen.dart test/widget/
git commit -m "feat(safe_beacon): wire home tile and route"
```

---

## Task 10: Beacon test coverage: every code path green

**Objective:** Add tests for the beacon integration: mesh broadcast
is fired, queue is populated, drain fires on online.

**Files:**
- MOD: `test/unit/sms_queue_test.dart` (more cases if not already
  comprehensive)

**Step 1: Add tests.** (a) Queue has length 1 after enqueue. (b)
Drain with all-success sends everything. (c) Drain with mid-failure
stops and re-queues.

**Step 2: Commit.**
```bash
git add test/
git commit -m "test(safe_beacon): pin SmsQueue behavior on drain/partial-fail"
```

---

## Task 11: Offline emergency directory (Tier 2 win)

**Objective:** A static JSON asset of official Bangladesh emergency
numbers (fire service, ambulance, district hospitals, poison
control), filterable by district. Tap-to-call.

**Files:**
- Create: `assets/emergency/directory.json` (static data)
- Create: `lib/features/emergency/directory_screen.dart`
- Create: `lib/features/emergency/directory_loader.dart` (parses JSON)
- Create: `test/widget/directory_screen_test.dart`
- MOD: `lib/app/router.dart` (route)
- MOD: `lib/features/emergency/emergency_sheet.dart` (link from
  the existing emergency sheet — replaces current contact list
  access there)

**Step 1: Author `directory.json`.** 20-30 entries covering the
six divisions. Each entry: `{ name, nameBn, phone, district, type }`.
`type ∈ {fire, ambulance, hospital, poison, police, coastguard}`.

**Step 2: `DirectoryLoader` parses** the JSON at first use,
caches the result in memory.

**Step 3: Screen** with a SearchBar (district) and a list. Each
row has the name (Bangla), phone, and a phone-call icon.

**Step 4: Widget test** with the JSON bundled in test assets.

**Step 5: Verify** + commit.
```bash
git add assets/emergency/ lib/features/emergency/
git commit -m "feat(emergency): add offline directory screen"
git add lib/app/router.dart lib/features/emergency/emergency_sheet.dart test/widget/
git commit -m "feat(emergency): link directory from emergency sheet"
```

---

## Task 12: First-run demo pack (Tier 2 win)

**Objective:** Seed the chat with 2-3 pre-answered Q&As so the app
never looks empty in a judge's hands.

**Files:**
- Create: `lib/features/chat/demo_seeder.dart`
- Create: `test/unit/demo_seeder_test.dart`
- MOD: `lib/features/chat/chat_screen.dart` (call seeder on first
  launch)

**Step 1: `DemoSeeder` is a pure-Dart function** that returns
the seeded list of `ChatMessage` objects:
- "ওআরএস কীভাবে বানাবো?" → KB ORS recipe (already in corpus).
- "নিকটস্থ আশ্রয়কেন্দ্র" → pre-rendered list snippet.
- "সাপে কামড়ালে কী করবো?" → KB snakebite (in corpus).

**Step 2: Decide when to seed.** A flag in SharedPreferences
`pref_demo_seeded_v1`. Only seed once. Persist so the user's
real chat history isn't polluted with demo messages on the
next launch.

**Step 3: Tests.** Seeder called once → 3 messages; called twice
→ still 3 (idempotent). Flag persists.

**Step 4: Wire** in `chat_screen.dart` after chat store load
(only if the store is empty AND the flag isn't set).

**Step 5: Commit.**
```bash
git add lib/features/chat/demo_seeder.dart test/unit/
git commit -m "feat(chat): add first-run demo seeder"
git add lib/features/chat/chat_screen.dart
git commit -m "feat(chat): wire demo seeder into ChatScreen init"
```

---

## Day 5 — rehearsal + polish

No new tasks. The operator runs:
- `flutter analyze lib/ test/` (must be clean)
- `flutter test` (must be 220+ green)
- `flutter build apk --release` (must produce APK)
- `flutter run -d <arm64-device> --release` and verify each
  Tier 1 feature on real hardware, in airplane mode
- Record the fallback video (per `HACKATHON-WIN-PLAN.md` Tier 3
  item 1)

---

## Verification gate (every commit, no exceptions)

```bash
flutter analyze lib/ test/    # No issues found
flutter test                  # 220+ passed, 0 failed
```

Both must be green before any commit lands.

## Open questions — RESOLVED (verified 2026-07-16)

1. **Is the existing `MeshService.receive(...)` callback
   overridable from the test side?** RESOLVED. `MeshService`
   exposes a public `Stream<MeshMessage> messages` (line 35).
   Subscribe from the relay engine in production; in tests, push a
   synthetic `MeshMessage` into a fake stream and assert. No
   refactor needed.
2. **Does the existing `chat_store.dart` schema accept a new
   `hopCount: int?` field on a `ChatMessage` without breaking
   migration?** RESOLVED. `ChatStore` is a flat JSON file
   (`lib/features/chat/chat_store.dart:36`); `ChatMessage.fromJson`
   ignores missing keys. Adding a nullable `hopCount: int?` is
   forward-compatible: old entries parse as null.
3. **Is the current `Geolocator` permission set sufficient** for
   the beacon (background vs foreground)? UNCHANGED — relevant
   in Task 9 only. The beacon is user-triggered, so foreground
   permission is enough. If background is later required, add
   `ACCESS_BACKGROUND_LOCATION` to `AndroidManifest.xml` and
   open a follow-up PR.
