import 'package:url_launcher/url_launcher.dart';

/// Emergency dial actions via the cellular voice channel (tel: URIs).
///
/// Calls use the voice channel which frequently survives when mobile data
/// is down — a deliberate design decision (docs/prd.md §2).
///
/// Bangladesh emergency numbers:
///   - 999: national emergency (police / fire / ambulance gateway)
///   - 333: national disaster / government helpline
class EmergencyActions {
  static const police = '999';
  static const fire = '999';
  static const ambulance = '999';
  static const disaster = '333';

  /// Open the system dialer with [number] prefilled. Uses canLaunchUrl to
  /// guard against missing dialer (docs/architecture.md §9 failure modes).
  static Future<bool> dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri);
    }
    return false;
  }
}