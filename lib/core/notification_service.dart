import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'settings_store.dart';

/// Phone notifications for new alarms while the app is not on screen.
/// (When the app is open, the red banner + sound are used instead.)
class NotificationService with WidgetsBindingObserver {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _inForeground = true;
  int _nextId = 1;

  Future<void> init() async {
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      WidgetsBinding.instance.addObserver(this);
      _ready = true;
    } catch (_) {
      // Notifications are not available on this platform: ignore.
      _ready = false;
    }
  }

  /// Asks the person to allow notifications (Android 13+ and iOS).
  Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {
      // Ignore: the person can allow it later in the phone settings.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
  }

  /// Shows a notification, but only when the app is in the background.
  Future<void> showAlarm(String title, String body) async {
    if (!_ready || _inForeground) return;
    if (!SettingsStore.instance.notificationsEnabled) return;
    try {
      await _plugin.show(
        _nextId++,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'argus_alarms',
            'Patient alarms',
            channelDescription:
                'Alerts when a vital sign leaves its safe range',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {
      // Ignore: the in-app alarm still works.
    }
  }
}
