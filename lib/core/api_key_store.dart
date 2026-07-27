import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted on-device storage for sensitive keys (API keys, tokens).
///
/// Uses [FlutterSecureStorage] which wraps Android Keystore / iOS Keychain.
/// Keys are encrypted at rest and never leave the device.
///
/// Holds a *ring* of Gemini keys rather than one, because the free tier's
/// daily quota is per-key: when one is spent the app rotates to the next
/// instead of dropping to the corpus fallback for the rest of the day. See
/// [ApiKeyRing] for the rotation itself and [RemoteKeyService] for where the
/// ring comes from.
class ApiKeyStore {
  static const _geminiKeyLabel = 'gemini_api_key';
  static const _geminiKeysLabel = 'gemini_api_keys';
  static const _activeIndexLabel = 'gemini_api_key_index';
  static const _rotationDayLabel = 'gemini_api_key_rotation_day';

  final FlutterSecureStorage _storage;

  ApiKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Save the Gemini API key for cloud AI access.
  Future<void> saveKey(String key) async {
    await _storage.write(key: _geminiKeyLabel, value: key);
  }

  /// Retrieve the Gemini API key. Returns null if not set.
  Future<String?> getKey() async {
    return await _storage.read(key: _geminiKeyLabel);
  }

  /// Whether a key has been stored.
  Future<bool> hasKey() async {
    final key = await _storage.read(key: _geminiKeyLabel);
    return key != null && key.isNotEmpty;
  }

  /// Delete the stored key (e.g., on logout or key rotation).
  Future<void> deleteKey() async {
    await _storage.delete(key: _geminiKeyLabel);
  }

  // ── Key ring ─────────────────────────────────────────────────────────

  /// Replace the stored ring. Blank entries and duplicates are dropped —
  /// the list is hand-edited in the Firebase console, and a duplicate would
  /// make the app "rotate" onto the same exhausted key.
  Future<void> saveKeys(List<String> keys) async {
    final cleaned = <String>[];
    for (final k in keys) {
      final t = k.trim();
      if (t.isNotEmpty && !cleaned.contains(t)) cleaned.add(t);
    }
    await _storage.write(key: _geminiKeysLabel, value: jsonEncode(cleaned));
    // Mirror the first key into the single-key slot so existing readers
    // (damage scanner, manual entry UI) keep working untouched.
    if (cleaned.isEmpty) {
      await deleteKey();
    } else {
      await saveKey(cleaned.first);
    }
  }

  /// The stored ring, newest write wins.
  ///
  /// Falls back to the single-key slot when no ring has been stored, so a
  /// device upgrading from the one-key build — or a user who typed a key
  /// into the app by hand — still gets a usable (length-1) ring.
  Future<List<String>> getKeys() async {
    try {
      final raw = await _storage.read(key: _geminiKeysLabel);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final keys = decoded.whereType<String>()
              .map((k) => k.trim())
              .where((k) => k.isNotEmpty)
              .toList();
          if (keys.isNotEmpty) return keys;
        }
      }
    } catch (e) {
      debugPrint('ApiKeyStore: getKeys failed, falling back to single key: $e');
    }
    final single = await getKey();
    return (single != null && single.trim().isNotEmpty)
        ? [single.trim()]
        : const [];
  }

  Future<void> deleteKeys() async {
    await _storage.delete(key: _geminiKeysLabel);
    await _storage.delete(key: _activeIndexLabel);
    await _storage.delete(key: _rotationDayLabel);
    await deleteKey();
  }

  /// Which key in the ring to start from.
  ///
  /// Returns 0 on a new UTC day regardless of what was stored: Gemini's free
  /// tier resets its daily quota, so a key abandoned yesterday is usable
  /// again today and there's no reason to keep burning the later ones. The
  /// reset boundary is approximate — Google's quota day is Pacific, not UTC —
  /// and the cost of being wrong is one failed request that rotates onward.
  Future<int> getActiveIndex() async {
    try {
      final storedDay = await _storage.read(key: _rotationDayLabel);
      if (storedDay != _todayUtc()) return 0;
      final raw = await _storage.read(key: _activeIndexLabel);
      final parsed = int.tryParse(raw ?? '');
      return (parsed == null || parsed < 0) ? 0 : parsed;
    } catch (e) {
      debugPrint('ApiKeyStore: getActiveIndex failed: $e');
      return 0;
    }
  }

  /// Remember which key is currently working, so the next launch doesn't
  /// re-burn a round trip on one that was already spent today.
  Future<void> saveActiveIndex(int index) async {
    try {
      await _storage.write(key: _activeIndexLabel, value: index.toString());
      await _storage.write(key: _rotationDayLabel, value: _todayUtc());
    } catch (e) {
      debugPrint('ApiKeyStore: saveActiveIndex failed: $e');
    }
  }

  static String _todayUtc() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month}-${now.day}';
  }
}
