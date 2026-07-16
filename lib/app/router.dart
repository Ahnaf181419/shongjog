import 'package:flutter/material.dart';

/// Route constants — push destinations. Top-level tabs live in [MainShell]
/// and do not use named routes.
class AppRoutes {
  static const settings = '/settings';
  static const emergencyContacts = '/emergency-contacts';
  static const about = '/about';
  static const meshRadar = '/mesh-radar';
  static const triage = '/triage';
  static const safeBeacon = '/safe-beacon';
  static const directory = '/directory';
}

/// Push a named route only if the current route is not already that route.
/// Prevents duplicate stack entries from rapid double-taps.
void pushNamedSafe(BuildContext context, String routeName) {
  final current = ModalRoute.of(context)?.settings.name;
  if (current == routeName) return;
  Navigator.pushNamed(context, routeName);
}

