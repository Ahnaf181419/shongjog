import 'package:flutter_test/flutter_test.dart';
import 'package:shongjog/features/emergency/sos_sms_template.dart';

void main() {
  group('sosSmsBody', () {
    test('includes emergency cue, name, phone, and coords', () {
      final s = sosSmsBody(
        name: 'রহিম',
        phone: '01712345678',
        lat: 23.81,
        lon: 90.41,
      );
      expect(s, contains('জরুরি'));
      expect(s, contains('রহিম'));
      expect(s, contains('01712345678'));
      expect(s, contains('23.81'));
      expect(s, contains('90.41'));
    });

    test('includes a clickable maps link', () {
      final s = sosSmsBody(
        name: 'করিম',
        phone: '01800000000',
        lat: 22.7,
        lon: 89.5,
      );
      expect(s, contains('https://maps.google.com/?q=22.7,89.5'));
    });

    test('handles negative coordinates (southern/western hemisphere)', () {
      final s = sosSmsBody(
        name: 'X',
        phone: '123',
        lat: -22.7,
        lon: -89.5,
      );
      expect(s, contains('-22.7'));
      expect(s, contains('-89.5'));
    });

    test('does NOT silently send 0,0 when GPS is missing', () {
      final s = sosSmsBody(
        name: 'রহিম',
        phone: '01712345678',
        lat: null,
        lon: null,
        gpsWarning: 'GPS অনুমতি দেওয়া হয়নি',
      );
      expect(s, contains('GPS অনুমতি দেওয়া হয়নি'));
      // Crucially: must NOT contain "0.0,0.0" or the Atlantic Ocean maps URL.
      expect(s, isNot(contains('0.0,0.0')));
      expect(s, isNot(contains('maps.google.com/?q=0')));
    });

    test('falls back to generic warning when gpsWarning is null but coords are null', () {
      final s = sosSmsBody(
        name: 'X',
        phone: '123',
        lat: null,
        lon: null,
      );
      expect(s, contains('GPS অনুপলব্ধ'));
    });
  });
}