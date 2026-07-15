import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny sound service for the two Shongjog audio identities:
///   - chime: 1.5s two-note rise, played on model-ready
///   - knock: 300ms water-drop, played when an answer renders
///
/// Per design.md §13.2, both are gated by a settings-screen toggle (default
/// on) and suppressed when system ringer is silent. Neither is crucial for
/// the demo — feature gracefully no-ops if a file fails to load.
class SoundService {
  final _chime = AudioPlayer();
  final _knock = AudioPlayer();
  bool _enabled = true;
  DateTime? _lastPlay;

  static const _prefKey = 'pref_sound_enabled';

  /// App-wide singleton — chat screen and settings screen both write here.
  static final SoundService instance = SoundService._();

  SoundService._();

  Future<void> init() async {
    try {
      await _chime.setReleaseMode(ReleaseMode.stop);
      await _knock.setReleaseMode(ReleaseMode.stop);
    } catch (_) {/* audioplayers init best-effort */}
    // Restore user toggle. Default true.
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? true;
    } catch (_) {/* stale prefs — keep default */}
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    // Persist for next launch. Fire-and-forget — settings UI doesn't await.
    SharedPreferences.getInstance().then((p) => p.setBool(_prefKey, enabled));
  }

  bool get isEnabled => _enabled;

  /// 5-second debounce so rapid actions don't queue many sounds.
  bool get _canPlay {
    final last = _lastPlay;
    if (last == null) return true;
    return DateTime.now().difference(last) > const Duration(seconds: 5);
  }

  Future<void> chime() async {
    if (!_enabled || !_canPlay) return;
    _lastPlay = DateTime.now();
    try {
      await _chime.play(AssetSource('sound/chime.wav'), volume: 0.6);
    } catch (_) {/* missing asset — silent */}
  }

  Future<void> knock() async {
    if (!_enabled || !_canPlay) return;
    _lastPlay = DateTime.now();
    try {
      await _knock.play(AssetSource('sound/knock.wav'), volume: 0.5);
    } catch (_) {/* missing asset — silent */}
  }

  Future<void> dispose() async {
    await _chime.dispose();
    await _knock.dispose();
  }
}
