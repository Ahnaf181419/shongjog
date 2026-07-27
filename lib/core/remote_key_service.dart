import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'api_key_store.dart';

/// Delivers the Gemini API key to installed apps without shipping it inside
/// the APK.
///
/// **Why this exists.** A key passed via `--dart-define` is compiled into
/// `libapp.so` as a plaintext literal — `strings libapp.so | grep AIzaSy`
/// recovers it from any public download in one command. Dart obfuscation
/// does not help: it renames symbols, not string constants. So a build that
/// is both publicly downloadable and carries a working key is a build whose
/// key is public, full stop.
///
/// Instead the APK ships with no key, and fetches one at first launch from
/// `config/cloud_ai` — readable by any signed-in (including anonymous)
/// device, writable by nobody through the client (see `firestore.rules`).
/// The fetched key is cached in [ApiKeyStore] (Android Keystore-backed), so
/// it survives relaunches and works offline afterwards.
///
/// **What this does and does not buy.** It removes the trivial `grep` path
/// and — the real point — makes the key *revocable*: change one Firestore
/// field and every installed device stops using it, with no new release.
/// It does NOT make the key secret from a determined attacker, who can pull
/// the Firebase config out of the APK, sign in anonymously, and read the same
/// doc. Treat the key as burnable: restrict it to the Generative Language
/// API in Cloud Console, cap its quota, and rotate it after judging.
///
/// The only way to make the key genuinely unreachable is to never send it to
/// the client — a server-side proxy holding it (Cloud Function or similar),
/// which needs a paid Firebase plan and is out of scope here.
class RemoteKeyService {
  RemoteKeyService({FirebaseFirestore? firestore, ApiKeyStore? keyStore})
      : _injectedFirestore = firestore,
        _keyStore = keyStore ?? ApiKeyStore();

  /// Document holding the shared demo keys. Not a collection of many docs —
  /// one row, edited by hand in the Firebase console.
  static const String collection = 'config';
  static const String document = 'cloud_ai';

  /// Array field holding the key ring. Gemini's free tier meters quota per
  /// key per day, so several keys let the app rotate past an exhausted one
  /// instead of losing cloud AI for the rest of the day.
  static const String listField = 'geminiApiKeys';

  /// Single-key field kept for the earlier one-key layout. Read as a
  /// fallback so an existing console doc keeps working.
  static const String field = 'geminiApiKey';

  // Resolved lazily — this runs from a top-level singleton constructed at
  // library load, before `Firebase.initializeApp()`, and
  // `FirebaseFirestore.instance` throws synchronously until then.
  final FirebaseFirestore? _injectedFirestore;
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  final ApiKeyStore _keyStore;

  /// Fetch the current key and cache it on the device.
  ///
  /// Returns true when a key was fetched and stored. Never throws: with no
  /// network, an unreadable doc, or no Firebase at all, the app simply keeps
  /// whatever key it already had — and with none, the chat falls through to
  /// on-device Gemma 4 and then the RAG corpus, exactly as it does offline.
  Future<bool> syncKey() async {
    try {
      final remote = await _fetchKeys();
      if (remote.isEmpty) return false;

      final current = await _keyStore.getKeys();
      if (_sameRing(current, remote)) return false; // unchanged, skip write
      await _keyStore.saveKeys(remote);
      debugPrint('RemoteKeyService: cloud AI key ring updated '
          '(${remote.length} key(s))');
      return true;
    } catch (e) {
      debugPrint('RemoteKeyService: syncKey failed: $e');
      return false;
    }
  }

  /// Drop every cached key. Called when the remote doc is emptied, so
  /// revoking in the console actually takes effect on device rather than
  /// leaving the last-known-good ring cached forever.
  Future<void> clearCachedKey() async {
    try {
      await _keyStore.deleteKeys();
    } catch (e) {
      debugPrint('RemoteKeyService: clearCachedKey failed: $e');
    }
  }

  /// [syncKey], plus honouring a deliberate revocation: an empty (or
  /// removed) key field clears the device's cached ring.
  Future<void> syncOrRevoke() async {
    try {
      final snap =
          await _firestore.collection(collection).doc(document).get();
      if (!snap.exists) return; // doc missing — leave the cache alone
      final remote = _parseKeys(snap.data());
      if (remote.isNotEmpty) {
        final current = await _keyStore.getKeys();
        if (!_sameRing(current, remote)) await _keyStore.saveKeys(remote);
        return;
      }
      // Field present but blank, or absent from an existing doc: an
      // explicit "stop using the shared keys".
      await clearCachedKey();
    } catch (e) {
      debugPrint('RemoteKeyService: syncOrRevoke failed: $e');
    }
  }

  Future<List<String>> _fetchKeys() async {
    final snap = await _firestore.collection(collection).doc(document).get();
    return _parseKeys(snap.data());
  }

  /// Read the ring from the config doc.
  ///
  /// Prefers the [listField] array; falls back to the single [field] string
  /// so a console doc written for the earlier one-key layout still works.
  /// Non-string array entries are skipped rather than crashing the parse —
  /// this doc is hand-edited, and one bad row must not take cloud AI down.
  static List<String> _parseKeys(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final list = data[listField];
    if (list is List) {
      final keys = list
          .whereType<String>()
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty)
          .toList();
      if (keys.isNotEmpty) return keys;
    }
    final single = data[field];
    if (single is String && single.trim().isNotEmpty) return [single.trim()];
    return const [];
  }

  static bool _sameRing(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// App-wide singleton — one per app instance.
final RemoteKeyService remoteKeyService = RemoteKeyService();
