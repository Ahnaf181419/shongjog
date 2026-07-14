import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's theme preference (light / dark / system) and persists it.
///
/// Wired into the root [MaterialApp] via [ListenableBuilder]. The 3-way choice
/// lives in Settings; default is [ThemeMode.system] (respects the OS setting).
class ThemeController extends ChangeNotifier {
  ThemeController() {
    _load();
  }

  static const _prefKey = 'pref_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    _mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }
}

/// Singleton accessor — use from anywhere via `themeController`.
final ThemeController themeController = ThemeController();
