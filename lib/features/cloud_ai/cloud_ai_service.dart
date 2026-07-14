import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class CloudAiService {
  final GenerativeModel _primaryModel;
  final GenerativeModel _fallbackModel;
  
  CloudAiService({required String apiKey}) 
      : _primaryModel = GenerativeModel(
          model: 'gemini-3.5-flash',
          apiKey: apiKey,
        ),
        _fallbackModel = GenerativeModel(
          model: 'gemini-3.1-flash-lite',
          apiKey: apiKey,
        );

  Future<bool> get isOnline async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return !connectivityResult.contains(ConnectivityResult.none) && connectivityResult.isNotEmpty;
  }

  Future<String> generate(String prompt) async {
    final content = [Content.text(prompt)];
    try {
      // Try the primary model first
      final response = await _primaryModel.generateContent(content);
      return response.text ?? 'কোনো উত্তর পাওয়া যায়নি।';
    } catch (e) {
      debugPrint('Primary model (3.5-flash) failed: $e, falling back to 3.1-flash-lite');
      try {
        // Fallback to the lighter model on failure (server traffic/error)
        final fallbackResponse = await _fallbackModel.generateContent(content);
        return fallbackResponse.text ?? 'কোনো উত্তর পাওয়া যায়নি।';
      } catch (e2) {
        throw Exception('Cloud AI request failed on both primary and fallback models.');
      }
    }
  }
}
