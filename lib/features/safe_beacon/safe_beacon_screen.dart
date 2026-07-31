import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/connectivity_provider.dart';
import '../../l10n/app_localizations.dart';
import '../contacts/contacts_repository.dart';
import '../emergency/emergency_actions.dart';
import '../mesh_comm/mesh_service.dart';
import 'safe_beacon_payload.dart';
import 'sms_queue.dart';
import '../../core/bangla_numerals.dart';

/// Convert Latin digits to Bengali numerals for UI strings.
/// "I'm safe" beacon — one giant Bangla button.
///
/// On tap:
/// 1. Reads the user's name/phone from SharedPreferences.
/// 2. Reads the user's emergency contacts from [ContactsRepository].
/// 3. Builds a [SafeBeaconPayload] and broadcasts it over the mesh
///    via [meshService.broadcastSos] (which the relay engine
///    then forwards hop-by-hop).
/// 4. Builds an "I'm safe" SMS body and queues one entry per
///    emergency contact via [SmsQueue].
/// 5. Listens to [connectivityProvider]; when the device goes
///    online, drains the queue (opens the SMS composer for each
///    queued contact via [EmergencyActions.sendSmsTo] (SmsManager).
class SafeBeaconScreen extends StatefulWidget {
  const SafeBeaconScreen({super.key});

  @override
  State<SafeBeaconScreen> createState() => _SafeBeaconScreenState();
}

class _SafeBeaconScreenState extends State<SafeBeaconScreen> {
  late final SmsQueue _queue;
  bool _sending = false;
  int _lastSentCount = 0;

  @override
  void initState() {
    super.initState();
    _queue = SmsQueue(_sendOne);
    // Drain if we're already online.
    if (connectivityProvider.isOnline) {
      _queue.drain().then((n) {
        if (mounted) setState(() => _lastSentCount = n);
      });
    }
    connectivityProvider.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    connectivityProvider.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  Future<bool> _sendOne(String body, String phone) async {
    final ok = await EmergencyActions.sendSmsTo(phone, body);
    return ok;
  }

  Future<void> _onConnectivityChanged() async {
    if (connectivityProvider.isOnline && _queue.pending > 0) {
      final n = await _queue.drain();
      if (mounted && n > 0) setState(() => _lastSentCount = n);
    }
  }

  String _safeMessage({
    required String name,
    required String phone,
    required double? lat,
    required double? lon,
  }) {
    final loc = (lat != null && lon != null)
        ? 'অবস্থান: https://maps.google.com/?q=$lat,$lon'
        : 'GPS অনুপলব্ধ';
    return 'আমি নিরাপদ আছি। '
        'আমি $name। ফোন: $phone। '
        '$loc। '
        'চিন্তা করবেন না।';
  }

  Future<void> _onTap() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name') ?? 'একজন ব্যবহারকারী';
      final phone = prefs.getString('user_phone') ?? '';

      // Get current GPS position via Geolocator (same pattern as
      // emergency_sheet.dart). Falls back gracefully if denied.
      double? lat;
      double? lon;
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
          lat = pos.latitude;
          lon = pos.longitude;
        }
      } catch (_) {
        // GPS unavailable — beacon still works, just without location.
      }

      final body = _safeMessage(
        name: name, phone: phone, lat: lat, lon: lon,
      );

      // 1. Broadcast over the mesh.
      meshService.ensureRelayEngine();
      final beacon = SafeBeaconPayload(
        id: 'safe-${DateTime.now().microsecondsSinceEpoch}',
        originName: name,
        originPhone: phone,
        lat: lat,
        lon: lon,
        timestamp: DateTime.now(),
        hopCount: 0,
        hops: const [],
      );
      meshService.broadcastSos(beacon.toSosPayload(message: body));

      // 2. Queue SMSes for every emergency contact.
      final contacts = await ContactsRepository.loadCustom();
      final phones = contacts
          .map((c) => c.phone)
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();
      for (final p in phones) {
        _queue.enqueue(body, p);
      }

      // 3. Try to drain immediately (online?) else wait for connectivity.
      int sent = 0;
      if (connectivityProvider.isOnline) {
        sent = await _queue.drain();
      }

      if (mounted) {
        setState(() => _lastSentCount = sent);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              phones.isEmpty
                  ? AppLocalizations.of(context).beaconSentPending(banglaNumber(_queue.pending))
                  : sent > 0
                      ? AppLocalizations.of(context).smsSent(banglaNumber(sent))
                      : AppLocalizations.of(context).willNotifyOnReconnect(banglaNumber(phones.length)),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).safeBeaconTitle),
        backgroundColor: cs.tertiaryContainer,
        foregroundColor: cs.onTertiaryContainer,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Icon(Icons.check_circle_outline_rounded,
                  size: 96, color: cs.tertiary),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context).safeBeaconDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _sending ? null : _onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.tertiary,
                    foregroundColor: cs.onTertiary,
                    minimumSize: const Size.fromHeight(140),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _sending
                      ? SizedBox(
                          height: 32, width: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(AppLocalizations.of(context).safeBeaconButton),
                ),
              ),
              const SizedBox(height: 24),
              if (_lastSentCount > 0)
                Text(
                  AppLocalizations.of(context).lastSent(banglaNumber(_lastSentCount)),
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              if (_queue.pending > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    AppLocalizations.of(context).pendingWait(banglaNumber(_queue.pending)),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}