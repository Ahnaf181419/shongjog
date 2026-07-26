import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Signature of the platform call that actually raises a notification.
/// Swapped out in tests — [FlutterLocalNotificationsPlugin] is a hard
/// singleton with no injection seam, so the seam lives here instead.
typedef NotificationSink = Future<void> Function(
    int id, String title, String body);

/// System-tray notifications for admin broadcasts.
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

  /// Android notification channel. Created implicitly on first [show] by
  /// [AndroidNotificationChannelAction.createIfNotExists] (the plugin
  /// default), so there's no separate channel-registration step.
  static const String channelId = 'shongjog_broadcasts';
  static const String channelName = 'জরুরি ঘোষণা';
  static const String channelDescription =
      'কর্তৃপক্ষের পাঠানো জরুরি বার্তা';

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
          // @mipmap/ic_launcher always exists in a Flutter Android app, so
          // this needs no extra drawable in the res tree.
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
            // High, not max: an admin broadcast is urgent enough to make a
            // sound and appear as a heads-up card, but it is not a
            // full-screen alarm — the SOS flow owns that register.
            importance: Importance.high,
            priority: Priority.high,
            // Broadcasts are usually longer than one line; without this the
            // body is truncated to a single ellipsised row.
            styleInformation: BigTextStyleInformation(''),
          ),
        ),
      );
    } catch (e) {
      debugPrint('LocalNotificationService: show failed: $e');
    }
  }
}

/// App-wide singleton — one per app instance.
final LocalNotificationService localNotificationService =
    LocalNotificationService();
