import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted on-device storage for sensitive keys (API keys, tokens).
///
/// Uses [FlutterSecureStorage] which wraps Android Keystore / iOS Keychain.
/// Keys are encrypted at rest and never leave the device.
class ApiKeyStore {
  static const _geminiKeyLabel = 'gemini_api_key';
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
}
