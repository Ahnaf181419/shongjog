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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    final newLocale = switch (saved) {
      'en' => const Locale('en'),
      _ => const Locale('bn'),
    };
    if (_locale != newLocale) {
      _locale = newLocale;
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, locale.languageCode);
  }
}

/// Singleton accessor — use from anywhere via `localeController`.
final LocaleController localeController = LocaleController();
