import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's language preference (bn / en) and persists it.
///
/// Wired into the root [MaterialApp] via [ListenableBuilder]. Default is
/// Bangla ('bn'). The toggle lives in Settings; a language picker also
/// appears on the onboarding welcome page.
class LocaleController extends ChangeNotifier {
  LocaleController() {
    _load();
  }

  static const _prefKey = 'pref_locale';

  Locale _locale = const Locale('bn');
  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  bool get isBangla => _locale.languageCode == 'bn';

  Completer<void>? _readyCompleter;

  /// Resolves once the persisted locale has been restored from
  /// SharedPreferences. Call before any locale-dependent startup work
  /// (cache priming, quick-cards warm, etc.) so the first frame already
  /// renders in the user's chosen language instead of the default.
  Future<void> ensureLoaded() {
    if (_readyCompleter != null) return _readyCompleter!.future;
    final c = Completer<void>();
    _readyCompleter = c;
    if (_loadComplete) {
      c.complete();
      return c.future;
    }
    _pendingReady = c;
    return c.future;
  }

  bool _loadComplete = false;
  Completer<void>? _pendingReady;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      final newLocale = switch (saved) {
        'en' => const Locale('en'),
        'bn' => const Locale('bn'),
        _ => WidgetsBinding.instance.platformDispatcher.locale.languageCode.toLowerCase().startsWith('en')
            ? const Locale('en')
            : const Locale('bn'),
      };
      if (_locale != newLocale) {
        _locale = newLocale;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('LocaleController._load failed (using default bn): $e');
    } finally {
      _loadComplete = true;
      final pending = _pendingReady;
      _pendingReady = null;
      pending?.complete();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, locale.languageCode);
    } catch (e) {
      debugPrint('LocaleController.setLocale save failed: $e');
    }
  }
}

/// Singleton accessor — use from anywhere via `localeController`.
final LocaleController localeController = LocaleController();
