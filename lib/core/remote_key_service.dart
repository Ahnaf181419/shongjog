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

  /// Document holding the shared demo key. Not a collection of many docs —
  /// one row, edited by hand in the Firebase console.
  static const String collection = 'config';
  static const String document = 'cloud_ai';
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
      final snap =
          await _firestore.collection(collection).doc(document).get();
      final remote = snap.data()?[field];
      if (remote is! String || remote.trim().isEmpty) return false;

      final current = await _keyStore.getKey();
      if (current == remote) return false; // unchanged, skip the write
      await _keyStore.saveKey(remote.trim());
      debugPrint('RemoteKeyService: cloud AI key updated from remote config');
      return true;
    } catch (e) {
      debugPrint('RemoteKeyService: syncKey failed: $e');
      return false;
    }
  }

  /// Drop the cached key. Called when the remote doc is emptied, so
  /// revoking a key in the console actually takes effect on device rather
  /// than leaving the last-known-good one cached forever.
  Future<void> clearCachedKey() async {
    try {
      await _keyStore.deleteKey();
    } catch (e) {
      debugPrint('RemoteKeyService: clearCachedKey failed: $e');
    }
  }

  /// [syncKey], plus honouring a deliberate revocation: an empty (or
  /// removed) `geminiApiKey` field clears the device's cached key.
  Future<void> syncOrRevoke() async {
    try {
      final snap =
          await _firestore.collection(collection).doc(document).get();
      if (!snap.exists) return; // doc missing — leave the cache alone
      final remote = snap.data()?[field];
      if (remote is String && remote.trim().isNotEmpty) {
        final current = await _keyStore.getKey();
        if (current != remote.trim()) await _keyStore.saveKey(remote.trim());
        return;
      }
      // Field present but blank, or absent from an existing doc: an
      // explicit "stop using the shared key".
      await clearCachedKey();
    } catch (e) {
      debugPrint('RemoteKeyService: syncOrRevoke failed: $e');
    }
  }
}

/// App-wide singleton — one per app instance.
final RemoteKeyService remoteKeyService = RemoteKeyService();
