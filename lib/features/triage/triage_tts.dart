/// Abstract TTS port for the triage wizard. Pure-Dart interface in
/// the triage module so the wizard can be unit-tested without
/// pulling [flutter_tts]. The production binding wraps
/// `TtsService` from `features/voice/`.
abstract class TriageTts {
  Future<void> speak(String text);
  Future<void> stop();
}

/// No-op TTS used when the pref_auto_read flag is off or when the
/// runtime is unavailable. The default constructor — never speaks.
class SilentTriageTts implements TriageTts {
  const SilentTriageTts();
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

/// Production adapter that wraps a [TtsService]. Imported
/// lazily by the route builder so the unit test path stays
/// flutter_tts-free.
typedef TtsServiceLike = TriageTts;

/// Bridge from the existing [TtsService] in `features/voice/` to
/// the [TriageTts] interface. Constructed at runtime — never at
/// widget construction time — so tests that build the wizard
/// without one keep their null-is-silent contract.
class LiveTriageTts implements TriageTts {
  final Future<void> Function(String) _speak;
  final Future<void> Function() _stop;

  const LiveTriageTts(this._speak, this._stop);

  @override
  Future<void> speak(String text) => _speak(text);

  @override
  Future<void> stop() => _stop();
}

