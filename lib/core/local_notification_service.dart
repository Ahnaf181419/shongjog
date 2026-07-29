import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Signature of the platform call that actually raises a notification.
/// Swapped out in tests — [FlutterLocalNotificationsPlugin] is a hard
/// singleton with no injection seam, so the seam lives here instead.
typedef NotificationSink = Future<void> Function(
    int id, String title, String body);

/// System-tray notifications for admin broadcasts and incoming mesh calls.
///
/// **This is deliberately not FCM push.** Delivering to a phone whose app is
/// fully closed needs a server holding a service-account credential to call
/// the FCM HTTP v1 API — a client cannot send to other devices, and the
/// Cloud Function that would do it requires the paid Blaze plan. So this
/// rides the Firestore snapshot stream [AdminBroadcastService] already keeps
/// open: when a broadcast written by another device arrives, that device
/// raises the notification locally. The user-visible result is the same — a
/// real tray notification on every device, not just the admin's — with the
/// documented limit that this device's isolate must be alive to receive the
/// snapshot (foreground, or backgrounded but not yet reaped by Android).
///
/// Every method swallows its failures. A missing notification must never
/// take down an emergency app: the in-app bell on the home screen is the
/// source of truth, and this is an escalation on top of it.
class LocalNotificationService {
  LocalNotificationService();

  // ── Admin broadcast channel ──────────────────────────────────────────
  static const String channelId = 'shongjog_broadcasts';
  static const String channelName = 'জরুরি ঘোষণা';
  static const String channelDescription =
      'কর্তৃপক্ষের পাঠানো জরুরি বার্তা';

  // ── Incoming mesh call channel ────────────────────────────────────────
  static const String callChannelId = 'shongjog_calls';
  static const String callChannelName = 'মেশ কল';
  static const String callChannelDescription =
      'অফলাইন মেশ নেটওয়ার্ক থেকে আসা কল';

  /// Test seam — set to intercept [show] instead of hitting the platform
  /// channel. Mirrors `debugFilesDirOverride` on the persistence services.
  @visibleForTesting
  NotificationSink? debugSinkOverride;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  FlutterLocalNotificationsPlugin get _plugin =>
      FlutterLocalNotificationsPlugin();

  /// Set up the plugin and ask for the Android 13+ POST_NOTIFICATIONS
  /// runtime permission. Safe to call more than once.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (debugSinkOverride != null) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      // No-op below Android 13, where the permission is install-time.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('LocalNotificationService: initialize failed: $e');
    }
  }

  /// Raise a notification. [id] should be stable per message so the same
  /// broadcast arriving twice (e.g. a snapshot replay after reconnect)
  /// updates one notification rather than stacking duplicates.
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    final sink = debugSinkOverride;
    if (sink != null) {
      await sink(id, title, body);
      return;
    }
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
      );
    } catch (e) {
      debugPrint('LocalNotificationService: show failed: $e');
    }
  }

  /// Raise an incoming-call notification with max importance (heads-up +
  /// full-screen intent when backgrounded). [callerName] is the display
  /// name of the remote peer. [onTap] is invoked when the user taps the
  /// notification.
  Future<void> showCallNotification({
    required String callerName,
    required VoidCallback? onTap,
  }) async {
    if (debugSinkOverride != null) {
      await debugSinkOverride!(
        _callNotificationId,
        'মেশ কল',
        '$callerName আপনাকে কল করছে',
      );
      onTap?.call();
      return;
    }
    try {
      // Create the call notification channel on first use.
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          callChannelId,
          callChannelName,
          description: callChannelDescription,
          importance: Importance.max,
          enableVibration: true,
          enableLights: true,
        ),
      );

      await _plugin.show(
        id: _callNotificationId,
        title: 'মেশ কল',
        body: '$callerName আপনাকে কল করছে',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            callChannelId,
            callChannelName,
            channelDescription: callChannelDescription,
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            sound: const RawResourceAndroidNotificationSound('call_ringtone'),
            // Uses the default system ringtone if call_ringtone.raw is absent.
            styleInformation: const BigTextStyleInformation(''),
          ),
        ),
      );
    } catch (e) {
      debugPrint('LocalNotificationService: showCallNotification failed: $e');
    }
    onTap?.call();
  }

  /// Dismiss the incoming-call notification (e.g. when call is answered).
  Future<void> dismissCallNotification() async {
    try {
      await _plugin.cancel(id: _callNotificationId);
    } catch (_) {}
  }

  static const int _callNotificationId = 999001;
}

/// App-wide singleton — one per app instance.
final LocalNotificationService localNotificationService =
    LocalNotificationService();
