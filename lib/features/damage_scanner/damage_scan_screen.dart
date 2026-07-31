import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme.dart';
import '../../core/api_key_store.dart';
import '../../core/connectivity_provider.dart';
import '../cloud_ai/cloud_ai_service.dart';
import '../../l10n/app_localizations.dart';
import 'damage_scan_service.dart';

enum DamageErrorCode {
  photoFailed,
  internetRequired,
  apiKeyRequired,
  analyzeFailed,
}

class DamageScannerScreen extends StatefulWidget {
  const DamageScannerScreen({super.key});

  @override
  State<DamageScannerScreen> createState() => _DamageScannerScreenState();
}

class _DamageScannerScreenState extends State<DamageScannerScreen> {
  final _picker = ImagePicker();
  XFile? _image;
  DamageScanResult? _result;
  bool _loading = false;
  DamageErrorCode? _errorCode;
  String? _errorDetail;
  String _diagnostics = '';

  final _keyStore = ApiKeyStore();

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _errorCode = null;
      _errorDetail = null;
    });

    // ── Pre-flight: fail fast if the analysis can't possibly succeed.
    // Checking *before* picking saves the user from taking a photo only
    // to be told they're offline or have no API key.
    if (!connectivityProvider.isOnline) {
      final diag = await _captureDiagnostics();
      if (!mounted) return;
      setState(() {
        _errorCode = DamageErrorCode.internetRequired;
        _diagnostics = diag;
      });
      return;
    }
    final key = await _tryGetApiKey();
    if (!mounted) return;
    if (key == null || key.isEmpty) {
      final diag = await _captureDiagnostics();
      if (!mounted) return;
      setState(() {
        _errorCode = DamageErrorCode.apiKeyRequired;
        _diagnostics = diag;
      });
      return;
    }

    // ── Camera permission (gallery needs none on Android 13+).
    if (source == ImageSource.camera) {
      final status = await Permission.camera.status;
      if (status.isPermanentlyDenied) {
        if (!mounted) return;
        setState(() {
          _errorCode = DamageErrorCode.photoFailed;
          _errorDetail = 'Camera permission permanently denied. '
              'Please enable it in Settings.';
        });
        return;
      }
      if (!status.isGranted) {
        final result = await Permission.camera.request();
        if (!result.isGranted) {
          if (!mounted) return;
          setState(() {
            _errorCode = DamageErrorCode.photoFailed;
            _errorDetail = 'Camera permission denied.';
          });
          return;
        }
      }
    }

    // ── Pick the image (own try-catch so photo errors are not misreported
    // as analysis errors).
    XFile? x;
    try {
      // Downscale AT CAPTURE, before the bytes ever reach us.
      //
      // This used to be a bare pickImage(source: source). A current phone
      // shoots ~4000x3000; base64 inflates that to a 5-11 MB request body,
      // which over Bangladeshi mobile data mid-disaster is a 30s+ upload
      // that frequently just times out. The model gains nothing from those
      // pixels — damage classification is a coarse-grained judgement — so
      // this is ~20x less to send for an identical answer.
      x = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );
    } catch (e) {
      final diag = await _captureDiagnostics();
      if (!mounted) return;
      setState(() {
        _errorCode = DamageErrorCode.photoFailed;
        _errorDetail = _briefError(e);
        _diagnostics = diag;
      });
      return;
    }

    if (x != null && mounted) {
      setState(() => _image = x);
      await _analyze();
    }
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    final isOnline = connectivityProvider.isOnline;
    final keys = await _apiKeys();
    if (!mounted) return;
    if (!isOnline) {
      setState(() {
        _errorCode = DamageErrorCode.internetRequired;
        _errorDetail = null;
      });
      return;
    }
    if (keys.isEmpty) {
      setState(() {
        _errorCode = DamageErrorCode.apiKeyRequired;
        _errorDetail = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorCode = null;
      _errorDetail = null;
      _result = null;
    });

    try {
      final bytes = await File(_image!.path).readAsBytes();
      final body = DamageScanService.buildRequestBody(bytes);

      // Walk the key ring on key-fatal failures only (quota spent, key
      // blocked or revoked), exactly as CloudAiService does for chat. A
      // timeout or a 5xx hits every key identically, so retrying those
      // would just burn the ring and add minutes to an emergency answer.
      dynamic response;
      Object? lastError;
      for (final key in keys) {
        try {
          response = await _sendVisionRequest(key, body);
          lastError = null;
          break;
        } catch (e) {
          lastError = e;
          if (!CloudAiService.isKeyFatal(e)) break;
          debugPrint('[DamageScan] key rejected, rotating: ${_briefError(e)}');
        }
      }
      if (lastError != null) throw lastError;

      final raw = _extractText(response);
      final result = DamageScanResult.fromJsonString(raw ?? '');
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      final diag = await _captureDiagnostics();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorCode = DamageErrorCode.analyzeFailed;
        _errorDetail = _briefError(e);
        _diagnostics = diag;
      });
    }
  }

  /// Trim an exception for display.
  ///
  /// The request body carries the whole photo as base64, and a thrown
  /// exception embeds it — so `e.toString()` was rendering tens of thousands
  /// of characters of image data over the entire screen, burying the one line
  /// that actually said what went wrong.
  static String _briefError(Object e) {
    final s = e.toString();
    if (s.length <= 240) return s;
    return '${s.substring(0, 240)}…';
  }

  /// One line naming every precondition, captured when a failure occurs.
  /// Kept ASCII and short so it survives a screenshot.
  Future<String> _captureDiagnostics() async {
    String key;
    try {
      final k = await _keyStore.getKey();
      key = (k == null || k.isEmpty) ? 'none' : 'len=${k.length}';
    } catch (e) {
      key = 'read-failed';
    }
    return 'online=${connectivityProvider.isOnline}  key=$key';
  }

  /// Every key this device holds, best first.
  ///
  /// This read only the single-key slot before, so when key #0 was
  /// quota-exhausted the scanner was dead for the rest of the day while the
  /// chat — which walks the whole ring — carried on working. Same credential
  /// store, same ring, same rotation opportunity.
  Future<List<String>> _apiKeys() async {
    try {
      final ring = await _keyStore.getKeys();
      if (ring.isNotEmpty) return ring;
    } catch (_) {}
    const compiled =
        String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    return compiled.isEmpty ? const [] : [compiled];
  }

  Future<String?> _tryGetApiKey() async {
    final keys = await _apiKeys();
    return keys.isEmpty ? null : keys.first;
  }

  /// Overall budget for one vision call, response included.
  ///
  /// `connectionTimeout` bounds only the TCP handshake — a server that
  /// accepts the connection and then stalls held the spinner forever, with
  /// no cancel affordance anywhere on the screen. Generous because the
  /// request still carries an image, but finite.
  static const _requestTimeout = Duration(seconds: 45);

  Future<dynamic> _sendVisionRequest(
      String apiKey, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent');
      final req = await client.postUrl(uri);
      req.headers.set('x-goog-api-key', apiKey);
      req.headers.set('Content-Type', 'application/json; charset=utf-8');
      // add(utf8.encode(...)), never write(String).
      //
      // HttpClientRequest.write encodes with the request's `encoding`, which
      // defaults to LATIN-1. The prompt is Bangla, latin1 cannot represent a
      // single Bangla codepoint, and the call throws
      //   Invalid argument (string): Contains invalid characters
      // *before anything is sent*. So the damage scanner never reached the
      // network at all — the failure looked like an API error but no request
      // was ever made.
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close().timeout(_requestTimeout);
      final responseBody =
          await res.transform(utf8.decoder).join().timeout(_requestTimeout);
      if (res.statusCode >= 400) {
        throw Exception('HTTP ${res.statusCode}: $responseBody');
      }
      return jsonDecode(responseBody);
    } finally {
      client.close();
    }
  }

  String? _extractText(dynamic responseJson) {
    try {
      final m = responseJson as Map<String, dynamic>;
      final candidates = m['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final c = candidates.first as Map<String, dynamic>;
      final parts = (c['content'] as Map<String, dynamic>?)?['parts'] as List?;
      if (parts == null) return null;
      return parts
          .whereType<Map<String, dynamic>>()
          .where((p) => p.containsKey('text'))
          .map((p) => p['text'] as String)
          .join('');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.damageTitle)),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.damageAiAnalyzing,
                style: TextStyle(color: ShongjogTheme.inkSecondary)),
          ],
        ),
      );
    }
    if (_result != null) {
      return _ResultView(
        l10n: l10n,
        result: _result!,
        imagePath: _image?.path,
        onScanAnother: () => setState(() {
          _result = null;
          _image = null;
        }),
      );
    }
    if (_errorCode != null) {
      return _ErrorView(
        l10n: l10n,
        code: _errorCode!,
        detail: _errorDetail,
        diagnostics: _diagnostics,
        onRetry: () {
          setState(() {
            _errorCode = null;
            _errorDetail = null;
          });
        },
      );
    }
    return _buildIntro(l10n);
  }

  Widget _buildIntro(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.camera_alt_outlined,
              size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text(
            l10n.damageIntroBody,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(l10n.damageCamera),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(l10n.damageGallery),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.damageFeatureInfo,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final AppLocalizations l10n;
  final DamageScanResult result;
  final String? imagePath;
  final VoidCallback onScanAnother;
  const _ResultView({
    required this.l10n,
    required this.result,
    required this.imagePath,
    required this.onScanAnother,
  });

  @override
  Widget build(BuildContext context) {
    final sevColor = Color(result.severity.color);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imagePath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
              child: Image.file(File(imagePath!), fit: BoxFit.cover,
                  height: 220, width: double.infinity),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.damageTypeLabel,
                          style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(result.toBanglaType,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sevColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(ShongjogTheme.radiusSm),
                  border: Border.all(color: sevColor, width: 2),
                ),
                child: Column(
                  children: [
                    Text(result.toBanglaSeverity,
                        style: TextStyle(
                            color: sevColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    if (result.confidence > 0)
                      Text(
                        '${(result.confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: sevColor, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (result.description.isNotEmpty) ...[
            Text(l10n.damageDescLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(result.description, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 16),
          ],
          Text(l10n.damageRecommendLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sevColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: sevColor, width: 4)),
            ),
            child: Text(result.recommendation,
                style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onScanAnother,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.damageScanAnother),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final AppLocalizations l10n;
  final DamageErrorCode code;
  final String? detail;
  final VoidCallback onRetry;

  /// Precondition snapshot taken when the failure happened.
  ///
  /// Four unrelated faults land on this screen — offline, no cached key, the
  /// picker failing, the API call failing — and they need opposite actions.
  /// Reporting "the scanner doesn't work" without this is unactionable, and
  /// nobody debugging on a phone has logcat attached. Showing the state
  /// inline means one screenshot names the cause.
  final String diagnostics;

  const _ErrorView({
    required this.l10n,
    required this.code,
    this.detail,
    required this.onRetry,
    this.diagnostics = '',
  });

  @override
  Widget build(BuildContext context) {
    final message = switch (code) {
      DamageErrorCode.photoFailed => l10n.damagePhotoError(detail ?? ''),
      DamageErrorCode.internetRequired => l10n.damageInternetRequired,
      DamageErrorCode.apiKeyRequired => l10n.damageApiKeyRequired,
      DamageErrorCode.analyzeFailed => l10n.damageAnalyzeError(detail ?? ''),
    };
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          // Selectable so the text can be copied out of a real device rather
          // than retyped from a photo of a screen.
          SelectableText(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5)),
          if (diagnostics.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: ShongjogTheme.statusChip(context),
              child: SelectableText(
                diagnostics,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.damageTryAgain),
          ),
        ],
      ),
    );
  }
}
