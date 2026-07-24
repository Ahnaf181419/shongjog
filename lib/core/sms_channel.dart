import 'package:flutter/services.dart';

/// Thin wrapper around a platform MethodChannel that calls Android's
/// SmsManager.sendTextMessage() for silent background SMS sending.
class SmsChannel {
  static const _channel = MethodChannel('com.example.shongjog/sms');

  /// Send an SMS to [to] with [body] via SmsManager.
  /// Returns true on success, false on platform error.
  static Future<bool> send(String to, String body) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'sendSms',
        {'to': to, 'body': body},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
