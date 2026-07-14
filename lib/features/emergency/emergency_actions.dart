import 'package:url_launcher/url_launcher.dart';

/// Emergency actions via the cellular voice channel (tel: and sms: URIs).
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

  /// Open the SMS composer with a pre-drafted SOS body to 999.
  static Future<bool> sendSos(String body) async {
    final uri = Uri(scheme: 'sms', path: '999', query: 'body=$body');
    if (await canLaunchUrl(uri)) return launchUrl(uri);
    return false;
  }
}
