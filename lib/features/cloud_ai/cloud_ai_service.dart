import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/connectivity_provider.dart';
import '../../rag/prompt_builder.dart';
import '../../rag/types.dart';

/// Cloud AI service with multi-model routing.
///
/// Primary: Gemini 3.1 Flash Lite
/// Fallback: Gemini 3.1 Flash Lite (preview channel)
///
/// Bypasses the google_generative_ai SDK to send raw REST requests with
/// `thinkingConfig.thinkingBudget: 0`, which suppresses chain-of-thought
/// leaking into visible responses. The SDK (v0.4.7) does not expose this
/// parameter — see investigation notes.
///
/// **On model choice.** `gemma-4-31b-it` was primary until it was found to
/// fail on *every* call: it rejects `thinkingConfig` with a 400, and without
/// that parameter it streams its planning scratchpad into the answer instead
/// (see [stripGemmaReasoning]). Every request silently burned a round-trip
/// before falling through, so the fallback had been doing all the real work.
/// The earlier pair — `gemini-2.5-flash` / `gemini-2.0-flash-lite` — is no
/// longer usable either: the former 404s and the latter has a free-tier
/// quota of zero. Both models below were verified live against the project's
/// own key before being set here.
///
/// This is only the *online* tier. The offline thesis rests on Gemma 4
/// E2B/E4B running on-device via `modelManager`, which this file never
/// touches.
class CloudAiService {
  static const String primaryModelId = 'gemini-3.1-flash-lite';
  static const String fallbackModelId = 'gemini-3.1-flash-lite-preview';

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
    return _generateOrThrow(fallbackModelId, contents, 'কোনো উত্তর পাওয়া যায়নি।');
  }

  Future<String> generate(String prompt) async {
    return generateWithHistory(userMessage: prompt, history: const []);
  }

  /// Whether [modelId] accepts `generationConfig.thinkingConfig`.
  ///
  /// The Gemma models served through the Gemini REST API reject it outright
  /// with `400 INVALID_ARGUMENT: "Thinking budget is not supported for this
  /// model."` — so sending it unconditionally made every single call to the
  /// primary model fail, silently burning a round-trip before falling through
  /// to the fallback. Gemini models do support it, and that is what keeps
  /// their chain-of-thought out of the visible answer.
  @visibleForTesting
  static bool supportsThinkingConfig(String modelId) =>
      !modelId.toLowerCase().startsWith('gemma');

  /// A scratchpad bullet: `*   text` or `    *   text`.
  static final _reasoningBullet = RegExp(r'^\s*\*\s{2,}\S');

  /// A sentence terminator immediately followed by a Bangla character, with
  /// no space between. This is where Gemma glues the real answer onto the
  /// tail of its last scratchpad bullet.
  static final _gluePoint = RegExp(r'[।.?!]([ঀ-৿])');

  static final _latinWord = RegExp(r'[A-Za-z]{3,}');

  /// Strip the planning scratchpad Gemma emits before its real answer.
  ///
  /// Because [supportsThinkingConfig] is false for Gemma, we cannot ask the
  /// API to suppress its reasoning — it streams into the response body as an
  /// English bullet list ("User asks: … Role: … Constraint 1: …"), followed
  /// by the actual Bangla answer. Shipping that to someone mid-emergency is
  /// unacceptable, so we recover just the answer.
  ///
  /// Returns the cleaned answer, [raw] unchanged when there is no scratchpad,
  /// or **null** when a scratchpad is present but the answer cannot be
  /// recovered confidently — null tells [_generate] to fall through to the
  /// fallback model rather than show the user a page of English notes.
  @visibleForTesting
  static String? stripGemmaReasoning(String raw) {
    final lines = raw.split('\n');

    // Gate: only treat this as a scratchpad when the response *opens* with an
    // English bullet. A genuine Bangla answer may well use markdown bullets,
    // but it will not lead with Latin prose — so this avoids mangling good
    // output on the strength of formatting alone.
    var opensWithEnglishBullet = false;
    for (final l in lines) {
      if (l.trim().isEmpty) continue;
      opensWithEnglishBullet =
          _reasoningBullet.hasMatch(l) && _latinWord.hasMatch(l);
      break;
    }
    if (!opensWithEnglishBullet) return raw;

    var lastBullet = -1;
    for (var i = 0; i < lines.length; i++) {
      if (_reasoningBullet.hasMatch(lines[i])) lastBullet = i;
    }
    if (lastBullet == -1) return raw;

    final buf = StringBuffer();
    // The answer's first sentence is glued to the end of the final bullet.
    final glued = _gluePoint.allMatches(lines[lastBullet]).toList();
    if (glued.isNotEmpty) {
      buf.write(lines[lastBullet].substring(glued.last.start + 1));
    }
    for (var i = lastBullet + 1; i < lines.length; i++) {
      if (buf.isNotEmpty) buf.write('\n');
      buf.write(lines[i]);
    }

    final out = buf.toString().trim();
    // Too little recovered, or what we recovered still looks like notes —
    // better to fall through to the fallback model than to guess.
    if (out.length < 20) return null;
    if (_reasoningBullet.hasMatch(out.split('\n').first)) return null;
    return out;
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
        // Only sent to models that accept it — Gemma rejects the whole
        // request with a 400 otherwise. See [supportsThinkingConfig].
        if (supportsThinkingConfig(modelId))
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

    final text = _extractText(json);
    if (text == null) return null;

    // Models without thinkingConfig support leak their planning notes into
    // the answer, so recover the answer alone. A null here means the
    // scratchpad could not be separated out, and the caller falls through to
    // the fallback model — never show the user raw reasoning.
    if (!supportsThinkingConfig(modelId)) {
      final cleaned = stripGemmaReasoning(text);
      if (cleaned == null) {
        debugPrint('[$modelId] reasoning scratchpad unrecoverable — '
            'falling through to fallback model');
      }
      return cleaned;
    }
    return text;
  }

  Future<String> _generateOrThrow(
    String modelId,
    List<Map<String, Object?>> contents, [
    String fallback = 'কোনো উত্তর পাওয়া যায়নি।',
  ]) async {
    try {
      final text = await _generate(modelId, contents);
      return text ?? fallback;
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

class CloudAiUnavailableException implements Exception {
  final String message;
  CloudAiUnavailableException([this.message = 'Cloud AI unavailable']);
  @override
  String toString() => message;
}
