import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/connectivity_provider.dart';
import '../../rag/prompt_builder.dart';

/// Cloud AI service with multi-model routing.
///
/// Primary: Gemma 4 31B via Google AI Studio
/// Fallback: Gemini 3.1 Flash Lite via Gemini API
///
/// Bypasses the google_generative_ai SDK to send raw REST requests with
/// `thinkingConfig.thinkingBudget: 0`, which suppresses chain-of-thought
/// leaking into visible responses. The SDK (v0.4.7) does not expose this
/// parameter — see investigation notes.
class CloudAiService {
  static const String primaryModelId = 'gemma-4-31b-it';
  static const String fallbackModelId = 'gemini-3.1-flash-lite';

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  final String _apiKey;
  final http.Client _http;

  CloudAiService({required this._apiKey, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  Future<bool> get isOnline async => connectivityProvider.isOnline;

  Future<String> generateWithHistory({
    required String userMessage,
    required List<ChatTurn> history,
  }) async {
    // Defense in depth: ChatRepository already gates on connectivity, but a
    // direct caller in airplane mode should fail fast, not after a 10s
    // timeout per model in the chain.
    if (!await isOnline) {
      throw CloudAiUnavailableException('Device is offline');
    }

    final contents = <Map<String, Object?>>[];

    for (final turn in history) {
      contents.add({
        'role': turn.isUser ? 'user' : 'model',
        'parts': [{'text': turn.text}],
      });
    }

    contents.add({
      'role': 'user',
      'parts': [{'text': userMessage}],
    });

    // 1. Try primary with 10s timeout
    try {
      final text = await _generate(primaryModelId, contents);
      if (text != null) return text;
    } catch (e) {
      debugPrint('Primary ($primaryModelId) failed: $e');

      if (_isRateLimited(e)) {
        debugPrint('Rate limited on primary, retrying in 2s...');
        await Future.delayed(const Duration(seconds: 2));
        try {
          final retry = await _generate(primaryModelId, contents);
          if (retry != null) return retry;
        } catch (retryError) {
          debugPrint('Retry failed: $retryError');
        }
      }
    }

    // 2. Auto-switch to fallback
    return _generateOrThrow(fallbackModelId, contents);
  }

  Future<String> generate(String prompt) async {
    return generateWithHistory(userMessage: prompt, history: const []);
  }

  /// Raw REST call to Gemini API with thinking disabled.
  Future<String?> _generate(
    String modelId,
    List<Map<String, Object?>> contents,
  ) async {
    final uri = Uri.parse('$_baseUrl/models/$modelId:generateContent');
    final body = jsonEncode({
      'contents': contents,
      'systemInstruction': {
        'parts': [{'text': kSystemInstruction}],
      },
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
        'thinkingConfig': {'thinkingBudget': 0},
      },
    });

    final response = await _http
        .post(uri, headers: {
          'x-goog-api-key': _apiKey,
          'Content-Type': 'application/json',
        }, body: body)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode >= 400) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, Object?>;
    // Raw bodies can contain user medical queries — never log in release.
    if (kDebugMode) debugPrint('RAW[$modelId]: ${response.body}');

    return _extractText(json);
  }

  Future<String> _generateOrThrow(
    String modelId,
    List<Map<String, Object?>> contents,
  ) async {
    try {
      final text = await _generate(modelId, contents);
      return text ?? 'কোনো উত্তর পাওয়া যায়নি।';
    } catch (e) {
      debugPrint('Fallback ($modelId) also failed: $e');
      throw CloudAiUnavailableException();
    }
  }

  static String? _extractText(Map<String, Object?> json) {
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return null;
    final candidate = candidates.first as Map<String, Object?>;
    final content = candidate['content'] as Map<String, Object?>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) return null;
    return parts
        .whereType<Map<String, Object?>>()
        .where((p) => p.containsKey('text'))
        .map((p) => p['text'] as String)
        .join('');
  }

  bool _isRateLimited(Object e) {
    final errStr = e.toString().toLowerCase();
    return errStr.contains('429') || errStr.contains('resource exhausted');
  }
}

/// A single conversation turn for history.
class ChatTurn {
  final String text;
  final bool isUser;

  const ChatTurn({required this.text, required this.isUser});
}

class CloudAiUnavailableException implements Exception {
  final String message;
  CloudAiUnavailableException([this.message = 'Cloud AI unavailable']);
  @override
  String toString() => message;
}
