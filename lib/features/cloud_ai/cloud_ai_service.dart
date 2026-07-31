import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/connectivity_provider.dart';
import '../../rag/prompt_builder.dart';
import '../../rag/types.dart';
import 'api_key_ring.dart';

/// Cloud AI service with multi-model routing.
///
/// Primary:     Gemini 3.1 Flash Lite
/// Fallback:    Gemini 3.1 Flash Lite (preview channel)
/// Last resort: Gemma 4 26B-A4B (see [lastResortModelId])
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
/// quota of zero. All three models below were verified live against the
/// project's own keys before being set here.
///
/// This is only the *online* tier. The offline thesis rests on Gemma 4
/// E2B/E4B running on-device via `modelManager`, which this file never
/// touches.
class CloudAiService {
  static const String primaryModelId = 'gemini-3.1-flash-lite';
  static const String fallbackModelId = 'gemini-3.1-flash-lite-preview';

  /// Tried only after *both* Gemini models are gone.
  ///
  /// This is the lighter of the two Gemma models the Gemini REST API serves
  /// (26B total, ~4B active per token; the other is `gemma-4-31b-it`). It is
  /// deliberately last, not because of its size but because of two measured
  /// properties it shares with every hosted Gemma:
  ///
  /// 1. It rejects `thinkingConfig` with `400 INVALID_ARGUMENT`, so its
  ///    planning scratchpad is generated as visible tokens and has to be
  ///    salvaged after the fact by [stripGemmaReasoning] — which succeeds on
  ///    roughly half of real responses and returns null on the rest.
  /// 2. Generating that scratchpad costs 13–21s against ~2.5s for the Gemini
  ///    models (hence [timeoutFor]).
  ///
  /// So it is worth strictly less than either model above it, and worth more
  /// than the nothing that used to be here: before this, both Gemini models
  /// failing meant a thrown [CloudAiUnavailableException] and no answer.
  static const String lastResortModelId = 'gemma-4-26b-a4b-it';

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  final ApiKeyRing _keys;
  final http.Client _http;

  CloudAiService({required ApiKeyRing keys, http.Client? httpClient})
      // The field is private and the parameter is not — Dart has no private
      // named parameter, so an initializing formal can't express this.
      // ignore: prefer_initializing_formals
      : _keys = keys,
        _http = httpClient ?? http.Client();

  /// Convenience for the single-key callers (manual in-app key entry, the
  /// compile-time `--dart-define` fallback).
  CloudAiService.singleKey(String apiKey, {http.Client? httpClient})
      : this(keys: ApiKeyRing.single(apiKey), httpClient: httpClient);

  /// Whether any key is configured at all. False is a normal state: the app
  /// runs on on-device Gemma 4 and the RAG corpus with no cloud tier.
  bool get hasKey => _keys.isNotEmpty;

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

    if (_keys.isEmpty) {
      throw CloudAiUnavailableException('No API key configured');
    }
    _keys.beginRequest();

    // 1. Primary model, walking the key ring. A key-fatal error (daily quota
    //    spent, key blocked or revoked) means THIS key is done, not that the
    //    request is impossible — so step to the next key and retry rather
    //    than degrade. These errors come back in well under a second, so a
    //    full lap of four keys costs far less than one 10s timeout.
    while (true) {
      try {
        final text = await _generate(primaryModelId, contents);
        if (text != null) return text;
        break; // reached the model but got nothing usable — try the fallback
      } catch (e) {
        debugPrint('Primary ($primaryModelId) key #${_keys.activeIndex} '
            'failed: $e');
        if (isKeyFatal(e) && _keys.advance()) {
          debugPrint('Rotating to key #${_keys.activeIndex}');
          continue;
        }
        // Either the whole ring is spent, or this is not the key's fault
        // (5xx, timeout, a model-level rejection). Rotating again would burn
        // the remaining keys against the same wall.
        if (_isRateLimited(e)) {
          // Per-MINUTE burst limits do recover in seconds, unlike the daily
          // quota that rotation handles. Worth one short wait — but only
          // now, once rotating has stopped being an option.
          debugPrint('All keys rate limited, retrying in 2s...');
          await Future.delayed(const Duration(seconds: 2));
          try {
            final retry = await _generate(primaryModelId, contents);
            if (retry != null) return retry;
          } catch (retryError) {
            debugPrint('Retry failed: $retryError');
          }
        }
        break;
      }
    }

    // 2. Auto-switch to fallback model, on whichever key we ended up holding.
    try {
      final text = await _generate(fallbackModelId, contents);
      if (text != null) return text;
      debugPrint('Fallback ($fallbackModelId) returned nothing usable');
    } catch (e) {
      debugPrint('Fallback ($fallbackModelId) failed: $e');
    }

    // 3. Both Gemini models are gone. Gemma is slow and only sometimes
    //    salvageable, but the alternative at this point is no answer at all.
    return _generateOrThrow(lastResortModelId, contents, 'কোনো উত্তর পাওয়া যায়নি।');
  }

  Future<String> generate(String prompt) async {
    return generateWithHistory(userMessage: prompt, history: const []);
  }

  /// Whether [e] means *this key* is finished, as opposed to the request
  /// being impossible for everyone.
  ///
  /// Rotating is only worth it for the former. A 500, a timeout, or a
  /// model-level 404 hits every key identically, so trying the next three
  /// just spends them for nothing and adds latency to an emergency answer.
  ///
  /// Public (not `@visibleForTesting`) because the damage scanner walks the
  /// same key ring against the same API and must make the same rotate-or-stop
  /// decision — two copies of this predicate would drift.
  static bool isKeyFatal(Object e) {
    final s = e.toString().toUpperCase();
    // Daily/per-project quota spent.
    if (s.contains('RESOURCE_EXHAUSTED') || s.contains('HTTP 429')) return true;
    // Key disabled, restricted to other APIs, or the API turned off for the
    // project the key belongs to.
    if (s.contains('API_KEY_SERVICE_BLOCKED') ||
        s.contains('SERVICE_DISABLED') ||
        s.contains('PERMISSION_DENIED') ||
        s.contains('HTTP 403')) {
      return true;
    }
    // Malformed, revoked, or wrong-type credential.
    if (s.contains('API_KEY_INVALID') ||
        s.contains('UNAUTHENTICATED') ||
        s.contains('ACCESS_TOKEN_TYPE_UNSUPPORTED') ||
        s.contains('HTTP 401')) {
      return true;
    }
    return false;
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
  static bool supportsThinkingConfig(String modelId) => !_isGemma(modelId);

  static bool _isGemma(String modelId) =>
      modelId.toLowerCase().startsWith('gemma');

  /// Per-model request budget.
  ///
  /// Gemma is not merely a slower model — because it cannot be told to skip
  /// its chain-of-thought (see [supportsThinkingConfig]), it *generates* the
  /// whole planning scratchpad as visible tokens before it reaches the
  /// answer. Measured live: 13–21s, against ~2.5s for `gemini-3.1-flash-lite`
  /// on the same prompt. The shared 10s budget would therefore have timed out
  /// [lastResortModelId] on essentially every call, making it dead code that
  /// merely added 10s to an already-failing request.
  ///
  /// The long budget is affordable only because this model is last: nothing
  /// reaches it until both Gemini models have already failed.
  @visibleForTesting
  static Duration timeoutFor(String modelId) => _isGemma(modelId)
      ? const Duration(seconds: 35)
      : const Duration(seconds: 10);

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
          'x-goog-api-key': _keys.activeKey,
          'Content-Type': 'application/json',
        }, body: body)
        .timeout(timeoutFor(modelId));

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
      debugPrint('Last-resort model ($modelId) also failed: $e');
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
