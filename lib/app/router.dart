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
  static const adminLogin = '/admin-login';
  static const adminPanel = '/admin-panel';
  static const notifications = '/notifications';
  static const sosComposer = '/sos-composer';
  static const profile = '/profile';
  static const adminDashboard = '/admin-dashboard';
  static const adminUsers = '/admin-users';
  static const adminCampaigns = '/admin-campaigns';
  static const adminBroadcast = '/admin-broadcast';
  static const adminDangerList = '/admin-danger-list';
  static const planner = '/planner';
  static const kit = '/kit';
  static const risk = '/risk';
  static const damageScanner = '/damage-scanner';
  static const situationSummary = '/situation-summary';
  static const quickCardDetail = '/quick-card-detail';
}

/// Push a named route only if the current route is not already that route.
/// Prevents duplicate stack entries from rapid double-taps.
void pushNamedSafe(BuildContext context, String routeName) {
  final current = ModalRoute.of(context)?.settings.name;
  if (current == routeName) return;
  Navigator.pushNamed(context, routeName);
}

