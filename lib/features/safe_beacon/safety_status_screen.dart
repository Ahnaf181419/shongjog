import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bangla_numerals.dart';
import '../../core/connectivity_provider.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contacts_repository.dart';
import '../emergency/emergency_actions.dart';
import '../mesh_comm/mesh_service.dart';
import 'safety_status_service.dart';
import 'sms_queue.dart';
import '../../app/theme.dart';
import '../../core/firebase_auth_service.dart';

/// "I'm Safe" / "I'm in Danger" status screen.
///
/// Two big buttons:
/// - **Safe** (green): broadcasts a safe status, queues SMS to contacts.
/// - **Danger** (red): asks the user to pick a danger type, grabs GPS
///   automatically, broadcasts a danger status with location, and
///   queues SMS. The admin's dashboard shows the danger count + GPS.
class SafetyStatusScreen extends StatefulWidget {
  const SafetyStatusScreen({super.key});

  @override
  State<SafetyStatusScreen> createState() => _SafetyStatusScreenState();
}

class _SafetyStatusScreenState extends State<SafetyStatusScreen> {
  late final SmsQueue _queue;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _queue = SmsQueue(_sendOne);
    connectivityProvider.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    connectivityProvider.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  Future<bool> _sendOne(String body, String phone) async {
    return EmergencyActions.sendSmsTo(phone, body);
  }

  Future<void> _onConnectivityChanged() async {
    if (connectivityProvider.isOnline && _queue.pending > 0) {
      await _queue.drain();
    }
  }

  Future<({String name, String phone, String userId})> _readProfile() async {
    // Capture the localized default BEFORE the await (lint:
    // use_build_context_synchronously).
    final defaultName = AppLocalizations.of(context).profileDefaultName;
    final prefs = await SharedPreferences.getInstance();
    return (
      // Locale-aware default (the report's userName surfaces in the
      // admin danger list and mesh peers' screens).
      name: prefs.getString('user_name') ?? defaultName,
      phone: prefs.getString('user_phone') ?? '',
      userId: await stableUserId(prefs),
    );
  }

  Future<({double? lat, double? lon})> _getGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return (lat: null, lon: null);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return (lat: pos.latitude, lon: pos.longitude);
    } catch (_) {
      return (lat: null, lon: null);
    }
  }

  // ── SAFE button ──────────────────────────────────────────────

  Future<void> _sendSafe() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final p = await _readProfile();

      // Audit F3 (2026-09-08): the safe beacon used to ship WITHOUT GPS
      // (null, null) — ported from the orphaned SafeBeaconScreen, whose
      // one-tap flow always tried a fix first. A safe message with a
      // location answers the family's real question ("WHERE are you
      // safe?") and fails soft when GPS is denied or times out.
      final gps = await _getGps();
      if (!mounted) return;

      final report = SafetyReport(
        id: 'safe-${DateTime.now().microsecondsSinceEpoch}',
        userId: p.userId,
        userName: p.name,
        userPhone: p.phone,
        status: SafetyReport.safeStatus,
        lat: gps.lat,
        lon: gps.lon,
        timestamp: DateTime.now(),
      );

      // 1. Record locally + broadcast over mesh.
      safetyStatusService.setMyReport(report);
      meshService.ensureRelayEngine();
      // jsonEncode, NOT '${report.toJson()}'. Interpolating the map calls
      // Map.toString(), which emits `{id: safe-1, …}` — not JSON — so every
      // receiver's jsonDecode threw and mesh safety relay silently did
      // nothing. See SafetyStatusService.ingestJson.
      meshService.sendMessage('SAFE:${jsonEncode(report.toJson())}',
          echoSelf: false);

      // 2. Queue SMS to contacts (with GPS when available).
      final sms = await _queueSms(
          _safeMessage(p.name, p.phone, gps.lat, gps.lon));

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        // Independent-review suggestion 2 (2026-09-09): when there are
        // no contacts configured, "will notify 0 on reconnect" is
        // misleading UX. Show an explicit "no contacts" branch.
        final content = sms.pending == 0 && sms.sent == 0
            ? l10n.safetyNoContacts
            : (sms.sent > 0
                ? l10n.smsSent(numberForLocale(sms.sent, l10n.localeName))
                : l10n.willNotifyOnReconnect(
                    numberForLocale(sms.pending, l10n.localeName)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Count-aware feedback, ported from SafeBeaconScreen: the
            // user must know whether contacts were notified now, will
            // be notified on reconnect, or there are none configured.
            content: Text(content),
            backgroundColor:
                ShongjogTheme.toneFill(context, SemanticTone.success),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── DANGER button ────────────────────────────────────────────

  Future<void> _sendDanger() async {
    if (_sending) return;

    // 1. Ask the user to pick a danger type.
    final dangerType = await showModalBottomSheet<DangerType>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DangerTypePicker(),
    );
    if (dangerType == null) return; // cancelled
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      final p = await _readProfile();

      // 2. Auto-grab GPS (critical for danger reports).
      final gps = await _getGps();

      final report = SafetyReport(
        id: 'danger-${DateTime.now().microsecondsSinceEpoch}',
        userId: p.userId,
        userName: p.name,
        userPhone: p.phone,
        status: SafetyReport.dangerStatus,
        dangerType: dangerType,
        lat: gps.lat,
        lon: gps.lon,
        timestamp: DateTime.now(),
      );

      // 3. Record locally + broadcast over mesh.
      safetyStatusService.setMyReport(report);
      meshService.ensureRelayEngine();
      // jsonEncode — see the note on the SAFE: send above.
      meshService.sendMessage('DANGER:${jsonEncode(report.toJson())}',
          echoSelf: false);

      // 4. Queue SMS to contacts (with GPS link).
      final sms = await _queueSms(
          _dangerMessage(p.name, p.phone, dangerType, gps.lat, gps.lon));

      if (mounted) {
        // Independent-review suggestion 3 (2026-09-09): mirror the
        // safe-path count-aware feedback so operators see the truth
        // (e.g. "৩টি এসএমএস পাঠানো হয়েছে, ২টি অপেক্ষমান").
        final content = sms.pending == 0 && sms.sent == 0
            ? l10n.safetyNoContacts
            : l10n.dangerSmsSummary(numberForLocale(sms.sent, l10n.localeName),
                numberForLocale(sms.pending, l10n.localeName));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(content),
            backgroundColor:
                ShongjogTheme.toneFill(context, SemanticTone.danger),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Queues the SMS body for every configured contact, then drains
  /// immediately if online. Returns counts so the caller can tell the
  /// user whether contacts were notified NOW, will be notified on
  /// reconnect, or there are none configured to notify.
  /// (Audit F3 — count-aware feedback ported from SafeBeaconScreen.)
  Future<({int sent, int pending})> _queueSms(String body) async {
    final contacts = await ContactsRepository.loadCustom();
    final phones = contacts
        .map((c) => c.phone)
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();
    for (final p in phones) {
      _queue.enqueue(body, p);
    }
    if (connectivityProvider.isOnline) {
      final sent = await _queue.drain();
      return (sent: sent, pending: phones.length - sent);
    }
    return (sent: 0, pending: phones.length);
  }

  String _safeMessage(String name, String phone, double? lat, double? lon) {
    final loc = (lat != null && lon != null)
        ? 'অবস্থান: https://maps.google.com/?q=$lat,$lon'
        : '';
    return 'আমি নিরাপদ আছি। আমি $name। ফোন: $phone।$loc';
  }

  String _dangerMessage(
      String name, String phone, DangerType type, double? lat, double? lon) {
    final loc = (lat != null && lon != null)
        ? ' অবস্থান: https://maps.google.com/?q=$lat,$lon'
        : '';
    return 'জরুরি! আমি বিপদে আছি। আমি $name। ফোন: $phone। '
        'সমস্যা: ${type.labelBn}।$loc';
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safetyStatusTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Icon(Icons.shield_rounded, size: 64, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                l10n.safetyStatusDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: cs.onSurfaceVariant),
              ),
              const Spacer(),

              // — DANGER button (red, top priority) —
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _sendDanger,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                ShongjogTheme.toneFill(context, SemanticTone.danger),
                    foregroundColor:
                        ShongjogTheme.onToneFill(context, SemanticTone.danger),
                    minimumSize: const Size.fromHeight(120),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ShongjogTheme.radiusLg)),
                    textStyle: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  icon: _sending
                      ? SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: ShongjogTheme.onToneFill(
                                  context, SemanticTone.danger)))
                      : const Icon(Icons.warning_rounded, size: 32),
                  label: Text(l10n.safetyDangerButton),
                ),
              ),
              const SizedBox(height: 16),

              // — SAFE button (green) —
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _sendSafe,
                  style: FilledButton.styleFrom(
                    backgroundColor:
                ShongjogTheme.toneFill(context, SemanticTone.success),
                    foregroundColor:
                        ShongjogTheme.onToneFill(context, SemanticTone.success),
                    minimumSize: const Size.fromHeight(120),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ShongjogTheme.radiusLg)),
                    textStyle: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  icon: _sending
                      ? SizedBox(
                          height: 24, width: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: ShongjogTheme.onToneFill(
                                  context, SemanticTone.success)))
                      : const Icon(Icons.check_circle_rounded, size: 32),
                  label: Text(l10n.safetySafeButton),
                ),
              ),

              const SizedBox(height: 16),
              // Current status indicator
              ListenableBuilder(
                listenable: safetyStatusService,
                builder: (context, _) {
                  final my = safetyStatusService.myReport;
                  if (my == null) {
                    return Text(l10n.safetyStatusNone,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 14));
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        my.isDanger ? Icons.warning_rounded : Icons.check_circle_rounded,
                        size: 16,
                        color: ShongjogTheme.toneInk(context,
                            my.isDanger ? SemanticTone.danger : SemanticTone.success),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        my.isDanger
                            ? '${l10n.safetyCurrentDanger}: ${my.dangerType?.label(l10n) ?? ''}'
                            : l10n.safetyCurrentSafe,
                        style: TextStyle(
                            color: ShongjogTheme.toneInk(context,
                                my.isDanger ? SemanticTone.danger : SemanticTone.success),
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Danger-type bottom-sheet picker ─────────────────────────────

class _DangerTypePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.dangerTypePickerTitle,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          const SizedBox(height: 4),
          Text(l10n.dangerTypePickerSubtitle,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final dt in DangerType.values)
                ActionChip(
                  label: Text(dt.label(l10n),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  avatar: Icon(_iconFor(dt), size: 18, color: cs.error),
                  onPressed: () => Navigator.of(context).pop(dt),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(DangerType dt) => switch (dt) {
        DangerType.flood => Icons.water_drop_rounded,
        DangerType.fire => Icons.local_fire_department_rounded,
        DangerType.earthquake => Icons.vibration_rounded,
        DangerType.cyclone => Icons.cyclone_rounded,
        DangerType.landslide => Icons.landscape_rounded,
        DangerType.trapped => Icons.do_not_step_rounded,
        DangerType.medical => Icons.medical_services_rounded,
        DangerType.violence => Icons.gavel_rounded,
        DangerType.other => Icons.help_outline_rounded,
      };
}
