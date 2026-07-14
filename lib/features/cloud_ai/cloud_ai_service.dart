import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Optional Cloud AI fallback for the RAG chain. Only invoked when the user
/// has configured `--dart-define=GEMINI_API_KEY=<...>` at build time AND the
/// device is online. The offline thesis still holds: without a key or without
/// network, the on-device Gemma fallback is used (docs/architecture.md §14).
class CloudAiService {
  // Pin to a real, live Google GenAI model identifier. The previous
  // `gemini-3.x-flash*` IDs were fictional and returned 404 on both primary
  // and fallback. As of Jan 2026 the stable line is 2.0/2.5 (verify at build).
  static const String primaryModelId = 'gemini-2.5-flash';
  static const String fallbackModelId = 'gemini-2.0-flash-lite';

  final GenerativeModel _primaryModel;
  final GenerativeModel _fallbackModel;

  CloudAiService({required String apiKey})
      : _primaryModel = GenerativeModel(
          model: primaryModelId,
          apiKey: apiKey,
        ),
        _fallbackModel = GenerativeModel(
          model: fallbackModelId,
          apiKey: apiKey,
        );

  Future<bool> get isOnline async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return !connectivityResult.contains(ConnectivityResult.none) && connectivityResult.isNotEmpty;
  }

  Future<String> generate(String prompt) async {
    final content = [Content.text(prompt)];
    try {
      final response = await _primaryModel.generateContent(content);
      return response.text ?? 'কোনো উত্তর পাওয়া যায়নি।';
    } catch (e) {
      debugPrint('Primary model ($primaryModelId) failed: $e, falling back to $fallbackModelId');
      try {
        final fallbackResponse = await _fallbackModel.generateContent(content);
        return fallbackResponse.text ?? 'কোনো উত্তর পাওয়া যায়নি।';
      } catch (e2) {
        throw Exception('Cloud AI request failed on both primary and fallback models.');
      }
    }
  }
}
