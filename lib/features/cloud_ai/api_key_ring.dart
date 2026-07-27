/// A rotating set of Gemini API keys.
///
/// Gemini's free tier meters quota **per key, per day**. With one key, the
/// first user to exhaust it takes cloud AI down for everyone until the next
/// reset. With four, the app steps to the next key the moment one reports
/// exhaustion and keeps answering.
///
/// This class is deliberately pure — no I/O, no Firestore, no storage — so
/// the rotation policy can be tested exhaustively. Persistence of
/// [activeIndex] across launches is the caller's job (see [ApiKeyStore]);
/// [onIndexChanged] is the hook for it.
class ApiKeyRing {
  ApiKeyRing({
    required List<String> keys,
    int startIndex = 0,
    this.onIndexChanged,
  })  : _keys = List.unmodifiable(
          keys.map((k) => k.trim()).where((k) => k.isNotEmpty),
        ),
        _index = 0 {
    // Clamp rather than throw: startIndex comes from storage written by a
    // previous run, and the ring may have shrunk since (a key removed in the
    // console). A stale index must not brick cloud AI.
    if (_keys.isNotEmpty) {
      _index = (startIndex >= 0 && startIndex < _keys.length) ? startIndex : 0;
    }
  }

  ApiKeyRing.single(String key) : this(keys: [key]);

  final List<String> _keys;
  int _index;

  /// How many keys have been tried in the current request. Reset by
  /// [beginRequest], so exhausting the ring on one message never stops the
  /// next message from trying again.
  int _triedThisRequest = 0;

  /// Called whenever rotation lands on a different key, so the caller can
  /// persist it. Not called for the transient per-request cycle reset.
  final void Function(int index)? onIndexChanged;

  List<String> get keys => _keys;
  int get length => _keys.length;
  bool get isEmpty => _keys.isEmpty;
  bool get isNotEmpty => _keys.isNotEmpty;

  int get activeIndex => _index;

  /// The key to use right now. Throws only if the ring is empty, which
  /// callers must check first — an empty ring means "no cloud AI configured",
  /// a normal state this app is built to run in.
  String get activeKey {
    if (_keys.isEmpty) {
      throw StateError('ApiKeyRing is empty — check isEmpty before use.');
    }
    return _keys[_index];
  }

  /// Start a new request. Clears the per-request try counter so [advance]
  /// gets a fresh full lap around the ring.
  void beginRequest() => _triedThisRequest = 0;

  /// Move to the next key after the current one failed in a way that
  /// implicates the key itself (quota, blocked, invalid).
  ///
  /// Returns false once every key has been tried during this request —
  /// meaning all four are spent and the caller should stop rotating rather
  /// than loop forever.
  bool advance() {
    if (_keys.length <= 1) return false;
    _triedThisRequest++;
    if (_triedThisRequest >= _keys.length) return false;
    _index = (_index + 1) % _keys.length;
    onIndexChanged?.call(_index);
    return true;
  }
}
