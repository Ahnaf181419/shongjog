# Profile & Voice-Call Mesh Hardening — Design Spec

**Date:** 2026-07-17
**Branch:** main
**Status:** Draft for review

---

## 1. Background

`shongjog` is an offline-first Bangla emergency-companion. The mesh
subsystem (`lib/features/mesh_comm/`) ships P2P_CLUSTER messaging over
Wi-Fi Direct with a multi-hop SOS relay already wired. After the
Phase A–E bug fixes (commit history through 2026-07-16), four adjacent
gaps surfaced:

1. **W1 — Profile identity.** A `ProfileScreen` exists with photo,
   district, and a 50-char name field, but the user's name never
   reaches the mesh advertising string. The mesh `userName` was a
   random `Shongjog-<6hex>` placeholder — peers in the radar see
   anonymous blobs, not humans.
2. **W2 — Walkie-talkie polish.** A complete PTT path exists
   (`MeshVoiceService.startRecording` /
   `stopRecordingAndSend` / `sendVoiceMessage`) but the chat UI is
   missing recording feedback, slide-to-cancel, voice-bubble playback
   progress, permission gating, and a known **double-stop race** that
   can flip `_recording = false` before the file is sent.
3. **W3 — Reliability.** `MeshService.start()` reports success or
   failure but does not surface degraded / hotspot-fallback states,
   so users have no indicator when peers drop. Leader arbitration
   doesn't exist — two devices can disagree on group ownership if the
   design is informal.
4. **W4 — UI audit.** The four touched screens (`home_screen`,
   `mesh_chat_screen`, `profile_screen`, `onboarding_screen`,
   `mesh_radar_screen`) have scattered glitches:
   `mesh_radar_screen.dart:143` typo "ব্লুটুভ" → "ব্লুটুথ",
   inline `Colors.green/red` instead of theme tokens, missing
   `SafeArea` on modal sheets, `autofocus: true` on the new
   optional name field, and assorted Latin numerals in user-facing
   copy.

## 2. Goals & non-goals

### 2.1 Goals (demo-shipping)

- **G1.** User enters their name in one place and it propagates to the
  mesh endpoint name seen in the radar.
- **G2.** PTT recording feels like WhatsApp: live timer, pulse,
  slide-to-cancel, voice-bubble waveform + duration, play progress.
- **G3.** Mesh state is visible at a glance on the home screen and the
  radar, with deterministic transitions between `cluster`,
  `degraded`, and `hotspot_fallback`.
- **G4.** Leader arbitration is automatic and conflict-free, with
  no wire-format change to the existing SOS relay.
- **G5.** All Bangla UI copy is rendered with correct numerals and
  consistent theme tokens; no Latin digits in user-facing strings; no
  raw `Colors.*` in user-facing widgets; known typos fixed.

### 2.2 Non-goals (post-hackathon backlog)

- **N1.** BLE out-of-band handshake. `requestPermissions` already
  requests `bluetoothScan` / `bluetoothAdvertise` / `bluetoothConnect`
  for the `nearby_connections` plugin's beaconing path. No actual
  BLE code is added; documented in `docs/POST-HACKATHON.md` §2.1.
- **N2.** Auto-promote peer to hotspot host via `WifiP2pManager.createGroup`
  / group-owner re-binding. Manual fallback only. Documented in
  `docs/POST-HACKATHON.md` §2.3.
- **N3.** Landscape / tablet / foldable layouts. Documented in
  §7.6.
- **N4.** Full TalkBack / VoiceOver routing for every focusable
  widget. We surface labels for primary actions only.
- **N5.** True full-duplex voice call. The transport, codec, and
  Android permission model do not support it on this stack. PTT
  walkie-talkie is the closest viable UX.

## 3. Brainstorm log (Q1–Q5)

| # | Question | Choice | Rationale |
|---|---|---|---|
| Q1 | Voice-call mode (BT full-duplex / Opus-over-P2P / walkie-talkie PTT) | **PTT walkie-talkie** over Wi-Fi Direct + hotspot fallback, BT as oob handshake / backup | Wi-Fi Direct P2P is the actual transport; BT full-duplex is not realistic; PTT matches the disaster-relief use-case better than a call (battery, attention, partial-duplex OK). |
| Q2 | PTT UX location (radar broadcast / per-peer chat / new tab) | **Per-peer chat only**, WhatsApp voice-note style | Matches user mental model; no new tab; one file change instead of three. |
| Q3 | Hotspot role model (auto-arbitrate / first-wins / lower-id wins) | **Lower-id peer = host, persistent Bangla banner** | Deterministic, no race, no two-leader confusion, no election chatter on the wire. |
| Q4 | BT oob handshake (full BLE ping / perms-only / drop perms) | **Keep perms, post-hackathon BLE ping** | Perms are already requested for the `nearby_connections` plugin's beaconing path; no runtime BLE code in this PR. |
| Q5 | Name fallback (random / model / model-then-name with onboarding input) | **Device-model fallback becomes `<name> · <model>` after name is set; optional input on onboarding welcome page** | Lets the radar be useful on first run before the user has typed anything; respects user consent. |

After Q1–Q5 the user said "ok go with your proposal" — the proposal
sequence is **W1 → W2 → W3 → W4**.

## 4. Workstreams

```
W1 — Profile identity         (sections 1, 3, 4)
W2 — Walkie-talkie polish     (section 5)
W3 — Reliability state machine (section 6)
W4 — UI audit                 (section 7)
```

---

## Section 1 — Profile editor hook (W1)

Existing `ProfileScreen` already has the editor (photo + district +
name). Do **not** rebuild. Three small edits:

### 1.1 `lib/features/profile/profile_screen.dart`

- Line ~240: `TextField(maxLength: 50)` → `maxLength: 100`.
- Add `String get displayName` to `UserProfileData` in the same file:
  ```dart
  String get displayName {
    final clean = name.trim();
    if (clean.isEmpty) return '';
    // Truncate at the first grapheme cluster boundary above 30 chars
    // so the chat bubble / AppBar stays one line on a 360dp phone.
    if (clean.characters.length <= 30) return clean;
    return '${clean.characters.take(30).toString()}…';
  }
  ```
  Add `import 'package:characters/characters.dart';` (already in
  Flutter SDK).
- In `_save()`, after the `prefs.setString('user_name', name)` call
  (line 144), call `meshIdentity.onProfileChanged()` (see §4.3).

### 1.2 `UserProfileData.hasPhoto`

Already exists. Use it in the home-screen nudge card (§3) to decide
whether the user still owes us a photo.

### 1.3 Combined snackbar

The save path shows a single snackbar. New copy:
`'প্রোফাইল ও মেশ পরিচয় সংরক্ষিত হয়েছে'` — replaces the existing
`'প্রোফাইল সংরক্ষিত হয়েছে'`.

---

## Section 3 — Onboarding welcome field + home nudge (W1)

### 3.1 Onboarding welcome page (`lib/features/onboarding/onboarding_screen.dart`)

Add an optional name `TextField` to `_welcomePage()` (line 90). Skip
is allowed.

```dart
// inside _welcomePage, after the body Text:
const SizedBox(height: 28),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 8),
  child: TextField(
    controller: _nameCtrl,
    autofocus: false,
    maxLength: 100,
    textInputAction: TextInputAction.next,
    onSubmitted: (_) => _next(),
    decoration: const InputDecoration(
      labelText: 'আপনার নাম (ঐচ্ছিক)',
      hintText: 'যেমন: রহিমা বেগম',
      border: OutlineInputBorder(),
      prefixIcon: Icon(Icons.person_outline_rounded),
    ),
  ),
),
```

`_goToHome` (line 52) writes `user_name` from `_nameCtrl.text.trim()`
*before* `pref_has_onboarded = true`, then calls
`meshIdentity.onProfileChanged()` to broadcast the new endpoint name
to the radar.

Per §7 finding O-3, the welcome column is wrapped in
`SingleChildScrollView` (currently `Column`) so it doesn't overflow
when the keyboard is up.

### 3.2 Home nudge card (`lib/features/home/home_screen.dart`)

Insert a `_ProfileNudgeCard` widget between `_HeroAskCard` and
`_EmergencyTriad`:

```dart
class _ProfileNudgeCard extends StatefulWidget {
  const _ProfileNudgeCard();
  @override
  State<_ProfileNudgeCard> createState() => _ProfileNudgeCardState();
}

class _ProfileNudgeCardState extends State<_ProfileNudgeCard> {
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {}); // refresh after async load
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snap) {
        final prefs = snap.data;
        if (prefs == null) return const SizedBox.shrink();
        if (prefs.getString('user_name')?.trim().isNotEmpty == true) {
          return const SizedBox.shrink();
        }
        if (prefs.getBool('pref_profile_nudge_dismissed') == true) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                await prefs.setBool(
                  'pref_profile_nudge_dismissed', true);
                if (!mounted) return;
                setState(() {});
                if (context.mounted) pushNamedSafe(context, AppRoutes.profile);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(children: [
                  Icon(Icons.person_add_alt_rounded,
                      color: cs.onSecondaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'আপনার নাম সেট করুন →',
                      style: TextStyle(
                        color: cs.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'বন্ধ করুন',
                    icon: Icon(Icons.close_rounded,
                        color: cs.onSecondaryContainer),
                    onPressed: () async {
                      await prefs.setBool(
                          'pref_profile_nudge_dismissed', true);
                      if (!mounted) return;
                      setState(() {});
                    },
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

Visibility rule:
`UserProfileData.name.isEmpty && pref_profile_nudge_dismissed == false`.
Dismiss on tap *and* close button both persist.

---

## Section 4 — MeshIdentity + restart (W1)

### 4.1 New singleton — `lib/features/profile/mesh_identity.dart`

```dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_screen.dart';

/// App-wide identity used by [MeshService] for advertising name and
/// for stable leader arbitration.  Loaded once from SharedPreferences
/// in main() before runApp; updates flow through [onProfileChanged].
class MeshIdentity extends ChangeNotifier {
  static const _kStableIdKey = 'pref_mesh_stable_id';
  static const _kEndpointNameKey = 'pref_mesh_endpoint_name';
  static const _kPrefix = 'Shongjog-';

  String _stableId = '';
  String _endpointName = '';

  String get stableId => _stableId;
  String get endpointName => _endpointName;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kStableIdKey);
    if (id == null || id.length != 6) {
      id = Random.secure().nextInt(0x1000000).toRadixString(16).padLeft(6, '0');
      await prefs.setString(_kStableIdKey, id);
    }
    _stableId = id;
    final saved = prefs.getString(_kEndpointNameKey);
    _endpointName = saved ?? '$_kPrefix$id';  // legacy fallback
    notifyListeners();
  }

  /// Called from profile save + onboarding finish. Returns true if
  /// the endpoint name actually changed (callers use this to decide
  /// whether the mesh needs a full restart).
  Future<bool> onProfileChanged() async {
    final profile = UserProfileData.load();
    final model = await _readDeviceModel();
    final next = _composeName(profile.name, model, _stableId);
    if (next == _endpointName) return false;
    _endpointName = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEndpointNameKey, next);
    notifyListeners();
    return true;
  }

  String _composeName(String name, String model, String stableId) {
    final cleanName = name.trim();
    final cleanModel = model.trim();
    if (cleanName.isEmpty) {
      return cleanModel.isEmpty ? '$_kPrefix$stableId' : cleanModel;
    }
    if (cleanModel.isEmpty) return cleanName;
    // 'রহিমা বেগম · Pixel 7' — Bangla middle dot, max 128 grapheme
    // clusters to keep the radar label one line on a 360dp phone.
    final composed = '$cleanName · $cleanModel';
    return composed.characters.length <= 128
        ? composed
        : '${composed.characters.take(128).toString()}…';
  }

  Future<String> _readDeviceModel() async {
    try {
      // DeviceCapability is the existing helper.
      return DeviceCapability.userFacingDeviceName();
    } catch (_) {
      return '';
    }
  }
}

final meshIdentity = MeshIdentity();
```

(Implementation note: `characters` extension is from
`package:characters/characters.dart`, already in the Flutter SDK. No
new dependency.)

### 4.2 `MeshService.userName` — `final` → `var`

In `lib/features/mesh_comm/mesh_service.dart`:

- Line 62: `final String userName;` → `String userName;`
- Line 482: replace the random-name factory with:
  ```dart
  final meshService = MeshService._(userName: '');

  void bootstrapMeshIdentity(String name) {
    meshService.userName = name;
  }
  ```

### 4.3 `MeshService.restart({String? newName})` — new method

```dart
Future<void> restart({String? newName}) async {
  if (newName != null) userName = newName;
  if (!_running) {
    await start();
    return;
  }
  // Full stop + clear + start.  Soft restart (restartDiscovery only)
  // is unreliable: nearby_connections caches the previous endpoint
  // name per service id and ignores the new bytes until the radio is
  // torn down, which is exactly the symptom we see when renaming
  // after a profile change.
  await Nearby().stopAdvertising();
  await Nearby().stopDiscovery();
  await Nearby().stopAllEndpoints();
  _peers.clear();
  _incomingFiles.clear();

  var advertisingOk = false;
  var discoveryOk  = false;
  try {
    advertisingOk = await Nearby().startAdvertising(
      userName, strategy, serviceId: _kServiceId,
      onConnectionInitiated: _onConnectionInitiated,
      onConnectionResult:   _onConnectionResult,
      onDisconnected:       _onDisconnected,
    );
  } catch (_) {}
  try {
    discoveryOk = await Nearby().startDiscovery(
      userName, strategy, serviceId: _kServiceId,
      onEndpointFound: _onEndpointFound,
      onEndpointLost:  _onEndpointLost,
    );
  } catch (_) {}

  _peersController.add(peerList);
}
```

### 4.4 `main.dart` — load identity before `runApp`

In `main()` between `adminBroadcastService.initialize()` and
`modelManager.autoSelectBestModel(...)`:

```dart
await meshIdentity.load();
// meshService was constructed with an empty userName; set it now
// so the first start() call advertises the correct name.
meshService.userName = meshIdentity.endpointName;
```

### 4.5 `_StartupGate` — restart on identity change

In `lib/app/app.dart`, after
`meshService.ensureRelayEngine();`:

```dart
meshIdentity.addListener(() {
  meshService.restart(newName: meshIdentity.endpointName);
});
```

Dispose the listener in `_StartupGate`'s `dispose()`.

---

## Section 5 — Walkie-talkie PTT polish (W2)

PTT already works end-to-end. This section is polish + two
reliability fixes.

### 5.1 `lib/features/mesh_comm/mesh_voice_service.dart`

- Add `numChannels: 1` to `RecordConfig` (cuts bandwidth in half).
- Guard `dispose()` against double-dispose with a `_disposed` flag.

### 5.2 `lib/features/mesh_comm/mesh_chat_screen.dart`

A fully rewritten `_toggleRecording` + `_handleAutoStop` +
`_recordingPill` + `_inputRow` + `StatefulWidget _MessageBubble`.
The diff is big enough to enumerate:

| Edit | Lines | What changes |
|---|---|---|
| A | imports | `import 'dart:async'`, `audioplayers`, `permission_handler` |
| B | state vars | add `_recordStart`, `_recordTicker`, `_recordElapsed`, `_recordCancelled`, `AudioPlayer _player`, `String? _playingMessageId` |
| C | `_toggleRecording` | race-free; permission gate before start |
| D | `_handleAutoStop` | new helper, calls `stopRecordingAndSend`, then `setState(() => _recording = false)`; ignored if `_recordCancelled` |
| E | ticker | `Timer.periodic(Duration(seconds: 1))` updates `_recordElapsed = now - _recordStart` |
| F | 5s warning haptic | in the ticker, when `_recordElapsed.inSeconds == 55`, `HapticService.warningHaptic()` |
| G | slide-to-cancel | a horizontal `GestureDetector` wrapping the mic button: `onHorizontalDragUpdate` updates `_dragOffset`; `onHorizontalDragEnd` with `|dx| > 80` triggers `_recordCancelled = true; meshVoiceService.stopRecording();` |
| H | `_recordingPill` | new widget overlay: pulsing red dot + MM:SS + "স্লাইড করে বাতিল" hint, replaces mic button while `_recording` |
| I | `_inputRow` | mic + text + send; **conditionally** shows `_recordingPill` overlay |
| J | `_MessageBubble` | `StatelessWidget` → `StatefulWidget`; holds an `AudioPlayer`; renders waveform placeholder (`Container(height: 4, decoration: …)` × 8), duration labels (`0:12 / 0:24`), play/pause toggle, `LinearProgressIndicator` while playing |
| K | on play failure | shows red `Icons.warning_rounded` + `'অডিও ব্যর্থ হয়েছে'` fallback text |

Permission gate:

```dart
Future<bool> _ensureMicPermission() async {
  final status = await Permission.microphone.status;
  if (status.isGranted) return true;
  final res = await Permission.microphone.request();
  if (!res.isGranted) {
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: cs.errorContainer,
      content: Text('মাইক অনুমতি প্রয়োজন — সেটিংসে দিন',
          style: TextStyle(color: cs.onErrorContainer)),
    ));
    return false;
  }
  return true;
}
```

Bugs fixed:

1. **Double-stop race.** The new `_handleAutoStop` awaits
   `stopRecordingAndSend` *before* flipping `_recording = false`. The
   `onAutoStop` callback is now just `_handleAutoStop()`.
2. **Empty bubble on voice-receive failure.** The renderer falls back
   to `'অডিও ব্যর্থ হয়েছে'` with a red `Icons.warning_rounded`
   instead of a silent `''` text and a non-functional play tap.

### 5.3 Tests

- New unit test in `test/unit/mesh_voice_service_test.dart`:
  `startRecording returns false without crashing on permission deny`.
- Widget test in `test/widget/mesh_chat_screen_test.dart`:
  `_MessageBubble renders fallback text when filePath is null`.

---

## Section 6 — Mesh reliability state machine (W3)

### 6.1 New types — `lib/features/mesh_comm/mesh_health.dart`

```dart
import 'package:flutter/foundation.dart';

enum MeshHealthState { cluster, degraded, hotspotFallback }

@immutable
class MeshHealth {
  final MeshHealthState state;
  final String? reason;          // 'no_peers' | 'wifi_off' | 'restarting'
  final DateTime updatedAt;
  final bool isLeader;           // local id < min(connected peer id)
  final int connectedPeerCount;
  final int ticksInDegraded;     // for 3-tick escalation rule

  const MeshHealth({
    required this.state,
    required this.reason,
    required this.updatedAt,
    required this.isLeader,
    required this.connectedPeerCount,
    required this.ticksInDegraded,
  });

  static MeshHealth starting() => MeshHealth(
        state: MeshHealthState.degraded,
        reason: 'starting',
        updatedAt: DateTime.now(),
        isLeader: false,
        connectedPeerCount: 0,
        ticksInDegraded: 0,
      );

  MeshHealth copyWith({
    MeshHealthState? state,
    String? reason,
    DateTime? updatedAt,
    bool? isLeader,
    int? connectedPeerCount,
    int? ticksInDegraded,
  }) =>
      MeshHealth(
        state: state ?? this.state,
        reason: reason ?? this.reason,
        updatedAt: updatedAt ?? this.updatedAt,
        isLeader: isLeader ?? this.isLeader,
        connectedPeerCount: connectedPeerCount ?? this.connectedPeerCount,
        ticksInDegraded: ticksInDegraded ?? this.ticksInDegraded,
      );

  String get banglaLabel => switch (state) {
        MeshHealthState.cluster =>
          connectedPeerCount == 0
              ? 'মেশ প্রস্তুত'
              : 'মেশ সক্রিয় · $connectedPeerCount জন',
        MeshHealthState.degraded =>
          reason == 'no_peers'
              ? 'কাছে কেউ নেই — খোঁজা হচ্ছে'
              : 'মেশ পুনরায় সংযোগ করছে',
        MeshHealthState.hotspotFallback =>
          'হটস্পট ফোলব্যাক প্রয়োজন',
      };
}
```

### 6.2 `MeshService` deltas

Three additive changes — `start()`, `stop()`, `_onConnectionResult`,
`_onEndpointLost` stay untouched except where noted.

```dart
// alongside _peersController:
final _healthController = StreamController<MeshHealth>.broadcast();
Stream<MeshHealth> get health => _healthController.stream;
MeshHealth _health = MeshHealth.starting();
MeshHealth get currentHealth => _health;

void _publishHealth(MeshHealth next) {
  if (next.state == _health.state &&
      next.reason == _health.reason &&
      next.connectedPeerCount == _health.connectedPeerCount &&
      next.isLeader == _health.isLeader) return;
  _health = next;
  _healthController.add(next);
}

Timer? _stateTicker;

void _startStateTicker() {
  _stateTicker?.cancel();
  _stateTicker = Timer.periodic(const Duration(seconds: 5), (_) {
    _tickHealth();
  });
}

void _tickHealth() {
  if (!_running) return;
  final hasPeers = _peers.values
      .any((p) => p.status == PeerStatus.connected);
  if (hasPeers) {
    _publishHealth(_health.copyWith(
      state: MeshHealthState.cluster,
      reason: null,
      ticksInDegraded: 0,
    ));
    _recomputeLeader();
    return;
  }
  final ticks = _health.ticksInDegraded + 1;
  if (ticks >= 3 && !_wifiOn) {
    _publishHealth(_health.copyWith(
      state: MeshHealthState.hotspotFallback,
      reason: 'wifi_off',
      ticksInDegraded: ticks,
    ));
  } else {
    _publishHealth(_health.copyWith(
      state: MeshHealthState.degraded,
      reason: 'no_peers',
      ticksInDegraded: ticks,
    ));
    restartDiscovery(); // light-touch recovery
  }
}

void _recomputeLeader() {
  final connected = _peers.values
      .where((p) => p.status == PeerStatus.connected)
      .map((p) => p.endpointId)
      .toList();
  if (connected.isEmpty) {
    _publishHealth(_health.copyWith(
      isLeader: false,
      connectedPeerCount: 0,
    ));
    return;
  }
  final minId = connected.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
  final amMin = minId.compareTo(meshIdentity.stableId) == 0;
  _publishHealth(_health.copyWith(
    isLeader: amMin,
    connectedPeerCount: connected.length,
  ));
}
```

`start()` ends with `_startStateTicker()` and a `_publishHealth(...)`
emitting `state: degraded, reason: 'starting'`.
`stop()` ends with `_stateTicker?.cancel(); _stateTicker = null;`.
`_onConnectionResult(CONNECTED)` calls `_recomputeLeader()`.
`_onEndpointLost` calls `_recomputeLeader()`.

### 6.3 UI surfaces

#### `_StatusStrip` — third chip (`home_screen.dart`)

Already has online + তথ্য-প্রস্তুত chips. Add a third:
icon + label = `meshService.currentHealth.banglaLabel`. Wrap the row
in `Wrap(spacing: 8, runSpacing: 8)` so chips fall to a second row
on 360 dp phones.

#### `_MeshHealthBanner` — new widget (`home_screen.dart`)

Persistent banner between `_StatusStrip` and `WeatherCard`; visible
**only in `degraded` or `hotspotFallback`**. Uses `ShongjogTheme.banner`
from §7.2. The hotspot-fallback variant has a trailing
`TextButton('হটস্পট চালু করুন')` that shows a
`SnackBar('Wi-Fi ও হটস্পট সেটিংস খুলুন')` in the demo build (no
runtime hotspot API hookup).

#### Radar peer tile (`mesh_radar_screen.dart`)

In `_PeerTile.build`, when `peer.endpointId == meshIdentity.stableId`,
sub-title is `'আপনি (নেতা)'`. Remote peers show their own state.
Leader is computed locally; no wire-format change.

### 6.4 Snackbar policy

| Transition | Reaction |
|---|---|
| cluster → degraded | nothing (banner appears via `StreamBuilder`) |
| degraded → hotspotFallback | `'Wi-Fi ফিরে আসছে — হটস্পট চালু করুন'` snackbar, **once per session** (flag) |
| degraded → cluster | `'Wi-Fi ফিরে এসেছে — মেশ সক্রিয়'` snackbar, once per 30 s (debounced) |

### 6.5 Tests

- `test/unit/mesh_health_test.dart`:
  1. `publishHealth suppresses redundant`
  2. `recomputeLeader picks min id` (peers `["c2","a9","f1"]`, local
     `b3` → `isLeader == false`; local `a9` → `true`)
  3. `stateTick escalates after 3 ticks when wifi off`
- `test/widget/mesh_health_banner_test.dart`:
  4. `MeshHealthBanner hides when cluster, shows when degraded`

---

## Section 7 — UI audit pass (W4)

### 7.1 Audit dimensions

A — Safe-area, B — Tap targets ≥ 48 dp, C — RTL/Bangla rendering,
D — Focus traversal, E — Theme tokens, F — Text-overflow safety,
G — Edge-to-edge on Android 15+, H — Keyboard-avoidance.

(Per-dimension pass criteria enumerated in session notes.)

### 7.2 Theme additions — `lib/app/theme.dart`

```dart
static const Color warning = Color(0xFFF59E0B); // amber-500
static const Color danger  = Color(0xFFDC2626); // red-600

static BoxDecoration banner(BuildContext context,
    {required bool severe}) { /* tinted container */ }

static SystemUiOverlayStyle overlayForBar(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness:
        isDark ? Brightness.light : Brightness.light,
    statusBarBrightness:
        isDark ? Brightness.dark : Brightness.light,
  );
}
```

### 7.3 Per-screen findings

#### `home_screen.dart`

- `_StatusStrip` row → `Wrap(spacing: 8, runSpacing: 8)`.
- `_StatusStrip` moved **above** the `ListView` (was inside).
- `_ProfileNudgeCard` adds `clipBehavior: Clip.antiAlias` and
  `maxLines: 2, overflow: ellipsis`.
- `Scaffold(body: AnnotatedRegion<SystemUiOverlayStyle>(
  value: ShongjogTheme.overlayForBar(context),
  child: …))`.

#### `mesh_chat_screen.dart`

- Bubble `maxWidth: 0.78` (small bump).
- `Flexible(child: Text(..., maxLines: 1, overflow: ellipsis))`
  wrapping duration.
- Snackbar uses `cs.errorContainer` / `cs.onErrorContainer`.
- `_recordingPill` height capped: `min(120, h * 0.25)`.

#### `profile_screen.dart`

- `showModalBottomSheet` builder wrapped in `SafeArea`.
- District dropdown sheet also `SafeArea`.
- `ElevatedButton` shows in-button spinner while `_saving`.
- `Text('সংরক্ষণ হচ্ছে...')` while saving.

#### `onboarding_screen.dart`

- New `TextField` with `autofocus: false`, `maxLength: 100`.
- Welcome page column wrapped in `SingleChildScrollView`.
- Bottom-bar `TextButton` wrapped in
  `ConstrainedBox(minHeight: 48, minWidth: 88)`.
- Back `IconButton` added to left of bottom bar when `_page > 0`.
- `HapticService.lightTap()` in `onPageChanged`.

#### `mesh_radar_screen.dart`

- Inline `Colors.green/red/orange` → `ShongjogTheme.success/danger/warning`.
- `'.toString().banglaDigits'` for the count chip.
- **Typo fix:** `'ব্লুটুভ সংযোগ চালু হচ্ছে...'` → `'ব্লুটুথ সংযোগ চালু হচ্ছে...'`
  (line 143).
- Snackbar uses `cs.errorContainer` / `cs.onErrorContainer`.

### 7.4 Cross-screen invariants

1. Never force `Directionality.rtl` on full-Bangla text; rely on
   Flutter's bidi default for `ltr` locale.
2. All user-facing numbers → `int.toBanglaDigits` (helper in
   `lib/core/format.dart`, ~12 lines).
3. All durations render with `:` (keep ASCII colon).
4. Every `Scaffold` with ocean `AppBar` wraps body in
   `AnnotatedRegion<SystemUiOverlayStyle>`.

### 7.5 Tests

- `test/widget/ui_audit_test.dart`:
  1. `_ProfileNudgeCard truncates long names`.
  2. `OnboardingScreen welcome scrolls when keyboard up`.
  3. `MeshRadarScreen peer tile uses theme tokens`.
- `test/unit/format_test.dart`:
  4. `toBanglaDigits` is correct and idempotent.

### 7.6 Out of scope (post-hackathon §2.4)

Landscape, tablet, TalkBack full pass, `disableAnimations`
compliance, RTL for Arabic/Urdu.

---

## 8. Acceptance criteria (demo-shipping)

Per `docs/PRE-DEMO.md`:

- `flutter analyze` — **No issues found**.
- `flutter test` — **321 pass + 1 skip** (was 284 + 1 pre-W1; +37
  tests across Sections 5, 6, 7).
- New files:
  - `lib/features/profile/mesh_identity.dart`
  - `lib/features/mesh_comm/mesh_health.dart`
  - `lib/core/format.dart`
- Touched files (~24 edits, every one described above):
  - `lib/features/profile/profile_screen.dart`
  - `lib/features/profile/district_data.dart` (no edit)
  - `lib/features/onboarding/onboarding_screen.dart`
  - `lib/features/home/home_screen.dart`
  - `lib/features/mesh_comm/mesh_service.dart`
  - `lib/features/mesh_comm/mesh_voice_service.dart`
  - `lib/features/mesh_comm/mesh_chat_screen.dart`
  - `lib/features/mesh_comm/mesh_radar_screen.dart`
  - `lib/features/mesh_comm/mesh_health.dart` (new)
  - `lib/app/app.dart`
  - `lib/app/theme.dart`
  - `lib/main.dart`
  - `lib/core/format.dart` (new)
- Wire-format: **unchanged**. No new bytes on the mesh; SOS relay
  intact (`SosPayload` schema identical).

## 9. Migration / rollback

- All edits are **additive** or **edit existing**. No file deletion.
- `mesh_service.userName` flips `final` → `var`; any caller using
  `MeshService.userName = X` after `start()` will be ignored —
  callers must use `restart(newName:)`.
- `MeshIdentity` writes `pref_mesh_stable_id` + `pref_mesh_endpoint_name`
  on first launch. Existing devices auto-migrate: missing keys → new
  stable id generated, endpoint name defaults to legacy random form.
- Rollback path: `git revert` of the implementing PR reverts all
  behavior; the new SharedPreferences keys are inert after rollback.

## 10. Open questions for reviewer

1. Is the 5-second `MeshHealthState.tick` interval right, or should
   we react faster (3 s) on the way down and slower (10 s) on the way
   up to avoid stuttering the radar?
2. Do we want a `MeshIdentity.logout()` (clears `pref_user_name`
   + nudges back to model fallback), or is that overkill for the demo?
3. The voice bubble `LinearProgressIndicator` is fine for shorter
   clips but won't scale past ~60 s visually. For the demo's
   max 60 s recording that's fine; flag for v2.

---

*End of spec.*
