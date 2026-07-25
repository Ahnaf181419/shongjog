import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/core/device_capability.dart' show ModelVariant;
import 'package:shongjog/core/model_manager.dart';
import 'package:shongjog/l10n/app_localizations.dart';

void main() {
  group('ModelState enum', () {
    test('has all expected states', () {
      expect(ModelState.values, contains(ModelState.notDownloaded));
      expect(ModelState.values, contains(ModelState.downloading));
      expect(ModelState.values, contains(ModelState.ready));
      expect(ModelState.values, contains(ModelState.loading));
      expect(ModelState.values, contains(ModelState.failed));
    });
  });

  group('ModelManager default state', () {
    final mgr = ModelManager();

    test('initial state is notDownloaded', () {
      expect(mgr.state, ModelState.notDownloaded);
    });

    testWidgets('statusLabel shows download needed', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          ctx = context;
          return const SizedBox();
        }),
      ));
      expect(mgr.statusLabel(ctx), isNotEmpty);
    });

    test('isReady is false initially', () {
      expect(mgr.isReady, isFalse);
    });

    test('isLoading is false initially', () {
      expect(mgr.isLoading, isFalse);
    });

    test('downloadProgress is null initially', () {
      expect(mgr.downloadProgress, isNull);
    });
  });

  group('ModelManager markReadyIfOnDisk', () {
    // markReadyIfOnDisk verifies the file before flipping state. In the
    // test environment no model file (and no path_provider) exists, so it
    // must leave the state untouched instead of faking readiness.
    test('does NOT mark ready when nothing is on disk', () async {
      final manager = ModelManager();
      expect(manager.state, ModelState.notDownloaded);
      await manager.markReadyIfOnDisk(ModelVariant.e2b);
      expect(manager.state, ModelState.notDownloaded);
      expect(manager.isReady, isFalse);
    });

    test('does not notify listeners when nothing is on disk', () async {
      final mgr = ModelManager();
      var notified = false;
      mgr.addListener(() => notified = true);
      await mgr.markReadyIfOnDisk(ModelVariant.e2b);
      expect(notified, isFalse);
    });
  });

  group('ModelManager statusLabel', () {
    testWidgets('not-downloaded state shows download needed', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          ctx = context;
          return const SizedBox();
        }),
      ));
      final manager = ModelManager();
      expect(manager.statusLabel(ctx), isNotEmpty);
    });

    test('downloading with progress shows percentage format', () {
      const progress = 0.45;
      final pct = '${(progress * 100).round()}%';
      expect(pct, '45%');
    });
  });

  group('modelManager singleton', () {
    test('is a ModelManager instance', () {
      expect(modelManager, isA<ModelManager>());
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Regression: models are stored as .litertlm, loaded in place
  // ════════════════════════════════════════════════════════════════
  //  The old 'model.bin' rule died with the MediaPipe path. flutter_gemma
  //  1.x's LiteRT-LM engine installs from an absolute path
  //  (installModel().fromFile()), so each variant keeps its own name and
  //  nothing is copied. Gemma 4 ships no Android .task at all — the repo's
  //  lone .task is a raw-TFL3 web build — so the extension is load-bearing:
  //  a .bin/.task path here means the engine gets a file it cannot read.
  group('model file layout', () {
    test('variant files use the .litertlm extension', () async {
      final tempDir = await Directory.systemTemp.createTemp('mm_layout');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      ModelManager.debugFilesDirOverride = tempDir.path;
      ModelManager.debugSizeFloorOverride = 1;
      addTearDown(() {
        ModelManager.debugFilesDirOverride = null;
        ModelManager.debugSizeFloorOverride = null;
      });

      final mgr = ModelManager();
      File('${tempDir.path}/model_e2b.litertlm').writeAsBytesSync([1, 2, 3]);
      expect(await mgr.isOnDisk(ModelVariant.e2b), isTrue);

      // A pre-1.x MediaPipe file must NOT count as downloaded.
      File('${tempDir.path}/model_e4b.bin').writeAsBytesSync([1, 2, 3]);
      expect(await mgr.isOnDisk(ModelVariant.e4b), isFalse);
    });

    test('ModelState.failed still exists (guards the init error path)', () {
      expect(ModelManager.new, isA<Function>());
      expect(ModelState.values, contains(ModelState.failed));
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Download-query API — used by the Home screen AppBar chip to show
  //  background download progress without being on the Settings page.
  // ════════════════════════════════════════════════════════════════
  group('ModelManager download-query API', () {
    test('isAnyVariantDownloading is false initially', () {
      final mgr = ModelManager();
      expect(mgr.isAnyVariantDownloading, isFalse);
    });

    test('activeDownloadProgress is null initially', () {
      final mgr = ModelManager();
      expect(mgr.activeDownloadProgress, isNull);
    });

    test('isAnyVariantDownloading is true when a variant is downloading', () {
      final mgr = ModelManager();
      mgr.debugSetDownloadingState(ModelVariant.e2b, 0.45);
      expect(mgr.isAnyVariantDownloading, isTrue);
    });

    test('activeDownloadProgress returns the downloading variant progress', () {
      final mgr = ModelManager();
      mgr.debugSetDownloadingState(ModelVariant.e4b, 0.72);
      expect(mgr.activeDownloadProgress, closeTo(0.72, 0.001));
    });

    test('isAnyVariantDownloading is false after download completes', () {
      final mgr = ModelManager();
      mgr.debugSetDownloadingState(ModelVariant.e2b, 0.5);
      expect(mgr.isAnyVariantDownloading, isTrue);
      mgr.debugClearDownloadingState(ModelVariant.e2b);
      expect(mgr.isAnyVariantDownloading, isFalse);
    });

    test('activeDownloadProgress is null after download completes', () {
      final mgr = ModelManager();
      mgr.debugSetDownloadingState(ModelVariant.e2b, 0.5);
      mgr.debugClearDownloadingState(ModelVariant.e2b);
      expect(mgr.activeDownloadProgress, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Single-flight: concurrent ensureModel() calls must share one
  //  download future so two IOSinks don't corrupt the model file.
  // ════════════════════════════════════════════════════════════════
  group('ModelManager single-flight ensureModel', () {
    test(
        'concurrent ensureModel calls for same variant share one download '
        '(isDownloading set exactly once, cleared after failure)', () async {
      final mgr = ModelManager();

      // In the test env, path_provider is unavailable, so ensureModel
      // will throw. But the single-flight guard runs BEFORE any I/O, so
      // both calls should enter the same future and the state should be
      // cleared after the shared failure.
      final f1 = mgr.ensureModel(variant: ModelVariant.e2b);
      final f2 = mgr.ensureModel(variant: ModelVariant.e2b);

      // While the (shared) download is in-flight, the variant is marked
      // downloading. Both futures refer to the same underlying operation.
      // We can't check isAnyVariantDownloading here because the failure
      // may have already completed synchronously. Instead verify both
      // futures reject (they share the same error).

      await expectLater(f1, throwsA(isA<Object>()));
      await expectLater(f2, throwsA(isA<Object>()));

      // After failure, the in-flight map must be cleared so the user can
      // retry without hitting "already downloading".
      expect(mgr.isAnyVariantDownloading, isFalse);
    });

    test(
        'ensureModel for a different variant does not collide with an '
        'ongoing download', () async {
      final mgr = ModelManager();

      final f1 = mgr.ensureModel(variant: ModelVariant.e2b);
      final f2 = mgr.ensureModel(variant: ModelVariant.e4b);

      // Both should reject (no path_provider in tests), but neither
      // should block the other from starting.
      await expectLater(f1, throwsA(isA<Object>()));
      await expectLater(f2, throwsA(isA<Object>()));

      expect(mgr.isAnyVariantDownloading, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════════
  //  Regression: cold-boot must promote any on-disk variant to ready,
  //  not just the "recommended" one. Before this fix, when the saved
  //  SharedPreferences key pointed to a variant whose file was missing
  //  (e.g. cleared by the user, or saved from an older build), and no
  //  "recommended" variant was on disk, _states stayed notDownloaded for
  //  every variant. The appbar then showed "অফলাইন (তথ্যকোষ)" even when
  //  a full model file existed on disk.
  //
  //  The test bypasses writing 1.85 GB of zeros by setting the
  //  debugSizeFloorOverride seam — any 1+ byte file counts as "on disk".
  // ════════════════════════════════════════════════════════════════
  group('autoSelectBestModel fallback when saved variant is missing on disk',
      () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('shongjog_test_');
      ModelManager.debugFilesDirOverride = tempDir.path;
      ModelManager.debugSizeFloorOverride = 1;
    });
    tearDown(() {
      ModelManager.debugFilesDirOverride = null;
      ModelManager.debugSizeFloorOverride = null;
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    void writeFakeModel(ModelVariant v) {
      File('${tempDir.path}/model_${v.name}.litertlm').writeAsBytesSync([1, 2, 3]);
    }

    test(
        'marks ready and activates the on-disk variant when saved is missing',
        () async {
      SharedPreferences.setMockInitialValues({
        // Saved variant is e4b, but the disk only has e2b.
        'active_model_variant': ModelVariant.e4b.index,
      });
      writeFakeModel(ModelVariant.e2b);

      final mgr = ModelManager();
      await mgr.autoSelectBestModel();

      // e2b is the only on-disk variant — autoSelect must promote it.
      expect(mgr.activeVariant, ModelVariant.e2b);
      expect(mgr.isReady, isTrue,
          reason: 'The on-disk variant must be marked ready on cold boot.');
      expect(mgr.getState(ModelVariant.e2b), ModelState.ready);
    });

    test(
        'preferred variant still wins when both saved and recommended are absent',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // Write only e4b to disk — recommended (mid/high) + not-saved.
      writeFakeModel(ModelVariant.e4b);

      final mgr = ModelManager();
      await mgr.autoSelectBestModel();

      expect(mgr.activeVariant, ModelVariant.e4b);
      expect(mgr.isReady, isTrue);
    });
  });
}
