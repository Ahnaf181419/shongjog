import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shongjog/l10n/app_localizations.dart';

/// Wraps [child] in a [MaterialApp] that provides the localization delegates
/// every screen now requires via [AppLocalizations.of].
/// Forces Bangla locale so tests match their hardcoded Bangla assertions.
Widget localizedApp(Widget child, {Map<String, WidgetBuilder>? routes}) {
  return MaterialApp(
    locale: const Locale('bn'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
    routes: routes ?? const {},
  );
}
