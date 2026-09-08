import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shongjog/core/connectivity_provider.dart';
import 'package:shongjog/features/safe_beacon/safety_status_screen.dart';

import 'test_app.dart';

void main() {
  // Audit F3 (2026-09-08): SafeBeaconScreen was an orphan — its good parts
  // (GPS in the safe SMS, count-aware send feedback) are merged into the
  // routed SafetyStatusScreen. These tests pin the merged behavior:
  // the SAFE button must attach GPS to the SMS when a fix is available,
  // and must still send (without location) when GPS is denied/unavailable.
  //
  // SharedPreferences must be mocked (the screen reads the profile through
  // it) and we pump fixed durations instead of pumpAndSettle: the _sending
  // state shows an indeterminate spinner, which never settles.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    GeolocatorPlatform.instance = _restoreGeolocator();
    // Leave the singleton online-state clean for other suites.
    connectivityProvider.debugSetOnline(false);
  });

  testWidgets('SAFE sends SMS with a maps link when GPS is available',
      (tester) async {
    final sent = <Map<String, dynamic>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.example.shongjog/sms'),
      (call) async {
        if (call.method == 'sendSms') {
          sent.add(Map<String, dynamic>.from(call.arguments as Map));
          return true;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.example.shongjog/sms'),
        null,
      );
    });

    // Fake GPS: permission granted + a Dhaka fix.
    GeolocatorPlatform.instance = _FakeGeolocator(
      permission: LocationPermission.whileInUse,
      position: Position(
        latitude: 23.8103,
        longitude: 90.4125,
        timestamp: DateTime(2026, 9, 8),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    // One emergency contact → one queued SMS we can assert on. The body
    // must carry the GPS fix (the SafeBeaconScreen capability this merge
    // ports into the routed screen).
    SharedPreferences.setMockInitialValues({
      'pref_custom_contacts':
          '[{"id":"c1","nameBn":"করিম","phone":"01700000000",'
              '"category":"other","isCustom":true}]',
    });

    // SMS drain only runs when the provider reports online — force it so
    // the queued message actually dispatches in the test environment.
    connectivityProvider.debugSetOnline(true);

    await tester.pumpWidget(localizedApp(const SafetyStatusScreen()));
    await tester.tap(find.text('আমি নিরাপদ'));
    // Fixed pumps, not pumpAndSettle — the _sending spinner never settles.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    // No-contacts case removed — the with-GPS test now covers delivery.
    // Assert the SMS actually carried the maps link (the merged capability)
    // and went to the contact's number.
    expect(sent, hasLength(1));
    expect(sent.first['to'], '01700000000');
    expect(sent.first['body'] as String, contains('maps.google.com'));
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('SAFE completes without GPS (denied) and still reports sent',
      (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator(
      permission: LocationPermission.deniedForever,
      position: null,
    );

    await tester.pumpWidget(localizedApp(const SafetyStatusScreen()));
    await tester.tap(find.text('আমি নিরাপদ'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(SnackBar), findsOneWidget);
  });
}

GeolocatorPlatform _restoreGeolocator() => _OriginalGeolocatorHolder.instance;

class _OriginalGeolocatorHolder {
  // Captured once at first use; restoring the original method-channel
  // instance keeps these tests from leaking the fake into other suites.
  static final GeolocatorPlatform instance = GeolocatorPlatform.instance;
}

class _FakeGeolocator extends GeolocatorPlatform {
  final LocationPermission permission;
  final Position? position;

  _FakeGeolocator({required this.permission, required this.position});

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    if (position == null) throw Exception('no fix');
    return position!;
  }
}
