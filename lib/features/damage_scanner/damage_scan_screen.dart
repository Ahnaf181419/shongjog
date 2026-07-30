import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme.dart';
import '../../core/api_key_store.dart';
import '../../core/connectivity_provider.dart';
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
      setState(() => _errorCode = DamageErrorCode.internetRequired);
      return;
    }
    final key = await _tryGetApiKey();
    if (!mounted) return;
    if (key == null || key.isEmpty) {
      setState(() => _errorCode = DamageErrorCode.apiKeyRequired);
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
      x = await _picker.pickImage(source: source);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCode = DamageErrorCode.photoFailed;
        _errorDetail = e.toString();
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
    final key = await _tryGetApiKey();
    if (!mounted) return;
    if (!isOnline) {
      setState(() {
        _errorCode = DamageErrorCode.internetRequired;
        _errorDetail = null;
      });
      return;
    }
    if (key == null || key.isEmpty) {
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
      final response = await _sendVisionRequest(key, body);
      final raw = _extractText(response);
      final result = DamageScanResult.fromJsonString(raw ?? '');
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorCode = DamageErrorCode.analyzeFailed;
        _errorDetail = e.toString();
      });
    }
  }

  Future<String?> _tryGetApiKey() async {
    try {
          final store = await _keyStore.getKey();
          if (store != null && store.isNotEmpty) return store;
        } catch (_) {}
        return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
      }

  Future<dynamic> _sendVisionRequest(
      String apiKey, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 15);
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent');
      final req = await client.postUrl(uri);
      req.headers.set('x-goog-api-key', apiKey);
      req.headers.set('Content-Type', 'application/json');
      req.write(jsonEncode(body));
      final res = await req.close();
      final responseBody = await res.transform(utf8.decoder).join();
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
  const _ErrorView({
    required this.l10n,
    required this.code,
    this.detail,
    required this.onRetry,
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
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5)),
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
