import 'package:url_launcher/url_launcher.dart';

import '../../core/sms_channel.dart';

/// Emergency actions via the cellular voice channel (tel: and SmsManager).
/// Bangladesh emergency numbers.
class EmergencyActions {
  // National hotlines (verified against BTRC + government directories).
  static const police = '999';
  static const fire = '16163';
  static const ambulance = '999';
  static const disaster = '333';
  static const redCrescent = '966';
  static const healthHotline = '16263';

  /// Open the system dialer with [number] prefilled.
  static Future<bool> dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) return launchUrl(uri);
    return false;
  }

  /// Send an SOS SMS to 999 silently via SmsManager.
  static Future<bool> sendSos(String body) {
    return SmsChannel.send('999', body);
  }

  /// Send an SMS with [body] to [phone] silently via SmsManager.
  static Future<bool> sendSmsTo(String phone, String body) {
    return SmsChannel.send(phone, body);
  }
}
