import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_capability.dart';

enum ModelState {
  notDownloaded,
  downloading,
  ready,
  loading,
  failed,
}

class ModelManager extends ChangeNotifier {
  static const _modelFileName = 'model.bin';
  static const _legacyFileName = 'gemma-4-E2B-it-web.task';
  static const _sizeTolerance = 0.99;

  ModelVariant _activeVariant = ModelVariant.e2b;
  ModelVariant get activeVariant => _activeVariant;

  final Map<ModelVariant, ModelState> _states = {
    ModelVariant.e2b: ModelState.notDownloaded,
    ModelVariant.e4b: ModelState.notDownloaded,
    ModelVariant.twelveb: ModelState.notDownloaded,
  };

  final Map<ModelVariant, double?> _progress = {
    ModelVariant.e2b: null,
    ModelVariant.e4b: null,
    ModelVariant.twelveb: null,
  };

  InferenceModel? _model;
  bool _initializing = false;

  ModelState get state => _states[_activeVariant]!;
  double? get downloadProgress => _progress[_activeVariant];

  ModelState getState(ModelVariant v) => _states[v]!;
  double? getProgress(ModelVariant v) => _progress[v];

  void _setState(ModelVariant v, ModelState s) {
    _states[v] = s;
    notifyListeners();
  }

  void _setProgress(ModelVariant v, double? p) {
    _progress[v] = p;
    notifyListeners();
  }

  /// Since flutter_gemma hardcodes 'model.bin', the active model is named 'model.bin'.
  /// Inactive downloaded models are named 'model_${variant.name}.bin'.
  Future<String> _pathForVariant(ModelVariant v) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/model_${v.name}.bin';
  }

  Future<String> _activeModelPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_modelFileName';
  }

  void markReadyIfOnDisk(ModelVariant v) {
    _setState(v, ModelState.ready);
  }

  Future<bool> isOnDisk(ModelVariant v) async {
    final path = await _pathForVariant(v);
    final f = File(path);
    if (!await f.exists()) return false;
    
    final recs = await DeviceCapability.getRecommendations();
    final rec = recs.firstWhere((r) => r.variant == v);
    
    final len = await f.length();
    return len >= (rec.sizeBytes * _sizeTolerance).round();
  }
  
  Future<bool> isAnyOnDisk() async {
    for (final v in ModelVariant.values) {
      if (await isOnDisk(v)) return true;
    }
    return false;
  }

  Future<void> ensureModel({
    ModelVariant? variant,
    void Function(double)? onProgress,
  }) async {
    final v = variant ?? _activeVariant;
    final recs = await DeviceCapability.getRecommendations();
    final rec = recs.firstWhere((r) => r.variant == v);

    final path = await _pathForVariant(v);
    final f = File(path);
    if (await f.exists() && await f.length() >= (rec.sizeBytes * _sizeTolerance).round()) {
      _setState(v, ModelState.ready);
      return;
    }

    _setState(v, ModelState.downloading);
    _setProgress(v, 0.0);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(seconds: 60);
    try {
      var existingBytes = 0;
      if (await f.exists()) {
        existingBytes = await f.length();
      }

      final req = await client.getUrl(Uri.parse(rec.downloadUrl));
      if (existingBytes > 0) {
        req.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
      }

      final resp = await req.close();

      var received = 0;
      IOSink sink;
      if (existingBytes > 0 && resp.statusCode == 206) {
        received = existingBytes;
        sink = f.openWrite(mode: FileMode.append);
      } else {
        received = 0;
        sink = f.openWrite(mode: FileMode.write);
      }

      final expectedTotal = resp.statusCode == 206
          ? (resp.contentLength > 0 ? resp.contentLength + existingBytes : 0)
          : (resp.contentLength > 0 ? resp.contentLength : 0);

      var lastNotifyTime = DateTime.fromMillisecondsSinceEpoch(0);
      var lastNotifiedPercent = -1;

      await for (final chunk in resp) {
        sink.add(chunk);
        received += chunk.length;
        if (expectedTotal > 0) {
          final fraction = (received / expectedTotal).clamp(0.0, 1.0);
          _setProgress(v, fraction);
          if (onProgress != null) onProgress(fraction);

          final now = DateTime.now();
          final currentPercent = (fraction * 100).floor();
          if (now.difference(lastNotifyTime) >= const Duration(seconds: 1) ||
              currentPercent != lastNotifiedPercent) {
            lastNotifyTime = now;
            lastNotifiedPercent = currentPercent;
            notifyListeners();
          }
        }
      }
      await sink.flush();
      await sink.close();

      if (received >= (rec.sizeBytes * _sizeTolerance).round()) {
        _setProgress(v, null);
        _setState(v, ModelState.ready);
      } else {
        _setProgress(v, null);
        _setState(v, ModelState.failed);
        throw Exception('Download incomplete: $received bytes (expected ~${rec.sizeBytes})');
      }
    } catch (e) {
      _setProgress(v, null);
      _setState(v, ModelState.failed);
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<InferenceModel> initialize() async {
    if (_model != null) return _model!;
    if (_initializing) {
      throw StateError('Model is already initializing');
    }
    
    final v = _activeVariant;
    if (!await isOnDisk(v)) {
      throw Exception('Active variant ${v.name} is not downloaded fully.');
    }
    
    _initializing = true;
    _setState(v, ModelState.loading);
    try {
      await _migrateOldFilename();
      
      final variantPath = await _pathForVariant(v);
      final activePath = await _activeModelPath();
      
      // Copy the specific variant to the required model.bin path if it's different
      final variantFile = File(variantPath);
      final activeFile = File(activePath);
      
      // We check size so we don't copy unnecessarily if it's already the same
      bool needsCopy = true;
      if (await activeFile.exists()) {
        if (await activeFile.length() == await variantFile.length()) {
          needsCopy = false;
        }
      }
      
      if (needsCopy) {
        if (await activeFile.exists()) await activeFile.delete();
        // Rename (move) is faster than copy. Since we want it accessible as model.bin.
        // Wait, if we switch back and forth, we need the original file. 
        // A copy is safest, even though it takes disk space. Let's try copy.
        await variantFile.copy(activePath);
      }
      
      await FlutterGemmaPlugin.instance.modelManager.setModelPath(activePath);
      _model = await FlutterGemmaPlugin.instance.init(
        maxTokens: 1024,
        temperature: 0.7,
      );
      _setState(v, ModelState.ready);
      return _model!;
    } catch (e) {
      _model = null;
      _setState(v, ModelState.failed);
      rethrow;
    } finally {
      _initializing = false;
    }
  }

  Future<void> _migrateOldFilename() async {
    final dir = await getApplicationDocumentsDirectory();
    final oldFile = File('${dir.path}/$_legacyFileName');
    if (await oldFile.exists()) {
      // Migrate it as the E2B variant
      final e2bPath = await _pathForVariant(ModelVariant.e2b);
      final newFile = File(e2bPath);
      if (await newFile.exists()) {
        await newFile.delete();
      }
      await oldFile.rename(e2bPath);
    }
  }

  Future<String> generate(String prompt) async {
    final model = await initialize();
    return model.getResponse(prompt: prompt);
  }

  bool get isReady => state == ModelState.ready;

  void resetSession() {
    _model = null;
    _initializing = false;
    // Don't reset states of downloaded files
  }

  void reset() {
    resetSession();
    _states[_activeVariant] = ModelState.notDownloaded;
    notifyListeners();
  }

  Future<void> deleteVariant(ModelVariant v) async {
    try {
      final path = await _pathForVariant(v);
      final f = File(path);
      if (await f.exists()) await f.delete();
      
      if (_activeVariant == v) {
         final activePath = await _activeModelPath();
         final activeFile = File(activePath);
         if (await activeFile.exists()) await activeFile.delete();
         resetSession();
      }
      
      _setState(v, ModelState.notDownloaded);
    } catch (e) {
      debugPrint('Failed to delete variant: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  Auto-select & initialization
  // ════════════════════════════════════════════════════════════════

  /// Auto-select the best model for this device on first run.
  ///
  /// Checks SharedPreferences for a previously saved variant preference.
  /// If none, selects the recommended variant based on hardware tier.
  /// If the recommended model is already on disk, marks it ready.
  Future<void> autoSelectBestModel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('active_model_variant');

    if (savedIndex != null && savedIndex < ModelVariant.values.length) {
      final saved = ModelVariant.values[savedIndex];
      if (await isOnDisk(saved)) {
        _activeVariant = saved;
        _setState(saved, ModelState.ready);
        return;
      }
    }

    // First run or saved model deleted — auto-select recommended
    final recommended = await DeviceCapability.getRecommendedVariant();
    _activeVariant = recommended;
    if (await isOnDisk(recommended)) {
      _setState(recommended, ModelState.ready);
    }
    notifyListeners();
  }

  /// Save the current active variant to SharedPreferences.
  Future<void> _saveActiveVariant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_model_variant', _activeVariant.index);
  }

  void setActiveVariant(ModelVariant v) {
    if (_activeVariant == v) return;
    resetSession();
    _activeVariant = v;
    _saveActiveVariant();
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════════
  //  Storage management
  // ════════════════════════════════════════════════════════════════

  /// Get total bytes used by all downloaded model files.
  Future<int> getStorageUsedBytes() async {
    int total = 0;
    for (final v in ModelVariant.values) {
      try {
        final path = await _pathForVariant(v);
        final f = File(path);
        if (await f.exists()) {
          total += await f.length();
        }
      } catch (_) {}
    }
    // Also count the active model.bin copy
    try {
      final activePath = await _activeModelPath();
      final activeFile = File(activePath);
      if (await activeFile.exists()) {
        total += await activeFile.length();
      }
    } catch (_) {}
    return total;
  }

  /// Get which variants are currently downloaded on disk.
  Future<List<ModelVariant>> getDownloadedVariants() async {
    final downloaded = <ModelVariant>[];
    for (final v in ModelVariant.values) {
      if (await isOnDisk(v)) {
        downloaded.add(v);
      }
    }
    return downloaded;
  }

  /// Get the size of a specific variant on disk (0 if not downloaded).
  Future<int> getVariantSizeBytes(ModelVariant v) async {
    try {
      final path = await _pathForVariant(v);
      final f = File(path);
      if (await f.exists()) return await f.length();
    } catch (_) {}
    return 0;
  }

  bool get isLoading =>
      state == ModelState.loading || state == ModelState.downloading;

  String get statusLabelBn {
    switch (state) {
      case ModelState.notDownloaded:
        return 'ডাউনলোড প্রয়োজন';
      case ModelState.downloading:
        final pct = downloadProgress != null
            ? '${(downloadProgress! * 100).round()}%'
            : '';
        return 'ডাউনলোড হচ্ছে $pct';
      case ModelState.ready:
        return 'প্রস্তুত';
      case ModelState.loading:
        return 'প্রস্তুত হচ্ছে...';
      case ModelState.failed:
        return 'ব্যর্থ';
    }
  }
}

final ModelManager modelManager = ModelManager();
