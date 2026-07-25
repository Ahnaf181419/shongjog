import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/api_key_store.dart';
import '../../core/connectivity_provider.dart';
import 'damage_scan_service.dart';

/// AI Damage Scanner screen (Module D in docs/AI-FIRST-FEATURES.md).
///
/// Flow:
/// 1. Pick / capture an image.
/// 2. Send to cloud Gemini via CloudAiService (vision-capable).
/// 3. Parse the JSON response into a DamageScanResult.
/// 4. Render damage type + severity badge + recommendation.
///
/// Requires internet + GEMINI_API_KEY. Shows a clear offline gate
/// when either is unavailable. The image never leaves the device
/// beyond this single explicit cloud call.
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
  String? _error;

  final _keyStore = ApiKeyStore();

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _error = null;
    });
    try {
      final x = await _picker.pickImage(source: source);
      if (x != null && mounted) {
        setState(() => _image = x);
        await _analyze();
      }
    } catch (e) {
      setState(() => _error = 'ছবি নেওয়া যায়নি: $e');
    }
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    final isOnline = connectivityProvider.isOnline;
    final key = await _tryGetApiKey();
    if (!mounted) return;
    if (!isOnline) {
      setState(() => _error = 'ড্যামেজ স্ক্যানের জন্য ইন্টারনেট প্রয়োজন।');
      return;
    }
    if (key == null || key.isEmpty) {
      setState(() => _error =
          'AI ড্যামেজ স্ক্যানের জন্য GEMINI_API_KEY প্রয়োজন। '
          'flutter run --dart-define=GEMINI_API_KEY=... দিয়ে চালান।');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
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
        _error = 'বিশ্লেষণ করা যায়নি: $e';
      });
    }
  }

  Future<String?> _tryGetApiKey() async {
    // Prefer the secure-store key, fall back to --dart-define.
    try {
          final store = await _keyStore.getKey();
          if (store != null && store.isNotEmpty) return store;
        } catch (_) {}
        return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
      }

  /// Send a vision request to Gemini. Uses the same raw REST endpoint
  /// as CloudAiService (gemini-3.1-flash-lite has vision). Built
  /// locally to avoid coupling the cloud_ai service to a multimodal
  /// payload shape.
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
    return Scaffold(
      appBar: AppBar(title: const Text('AI ড্যামেজ স্ক্যান')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('AI ছবি বিশ্লেষণ করছে…',
                style: TextStyle(color: ShongjogTheme.inkSecondary)),
          ],
        ),
      );
    }
    if (_result != null) {
      return _ResultView(
        result: _result!,
        imagePath: _image?.path,
        onScanAnother: () => setState(() {
          _result = null;
          _image = null;
        }),
      );
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: () {
        setState(() => _error = null);
      });
    }
    return _buildIntro();
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.camera_alt_outlined,
              size: 72, color: ShongjogTheme.ocean),
          const SizedBox(height: 24),
          const Text(
            'একটি ক্ষয়ক্ষতির ছবি তুলুন বা গ্যালারি থেকে নিন।\nAI ছবি দেখে ক্ষয়ক্ষতির ধরন ও তীব্রতা বলবে।',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('ক্যামেরা'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('গ্যালারি'),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ShongjogTheme.ocean.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'এই ফিচারের জন্য ইন্টারনেট ও GEMINI_API_KEY প্রয়োজন।',
                    style: TextStyle(fontSize: 12),
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
  final DamageScanResult result;
  final String? imagePath;
  final VoidCallback onScanAnother;
  const _ResultView({
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
              borderRadius: BorderRadius.circular(12),
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
                    color: ShongjogTheme.ocean.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ক্ষয়ক্ষতির ধরন',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                  borderRadius: BorderRadius.circular(12),
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
                        style: TextStyle(color: sevColor, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (result.description.isNotEmpty) ...[
            const Text('বিবরণ', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(result.description, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 16),
          ],
          const Text('সুপারিশ', style: TextStyle(fontWeight: FontWeight.w600)),
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
              icon: const Icon(Icons.refresh),
              label: const Text('আরেকটি ছবি স্ক্যান করুন'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64,
              color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.5)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('আবার চেষ্টা করুন'),
          ),
        ],
      ),
    );
  }
}

// JSON helpers live in dart:convert (jsonEncode / jsonDecode).