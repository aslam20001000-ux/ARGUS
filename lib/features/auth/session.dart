import 'package:flutter/material.dart';

import '../../core/alarm_service.dart';
import '../../core/background_monitor.dart';
import '../../core/device_service.dart';
import '../../core/app_state.dart';
import '../../core/auth_service.dart';
import '../../core/page_route.dart';
import '../../core/notification_service.dart';
import '../../core/profile_storage.dart';
import '../../core/settings_store.dart';
import '../../core/vitals_store.dart';
import '../home/feature_selection_page.dart';

/// Loads the account's saved profile, settings and alarm limits, shows the
/// signed-in person's name and starts reading data / watching alarms. Used
/// after login, after sign-up and when the app opens already signed in.
///
/// Each account is one person: their profile, settings and alarm limits are
/// saved under their account.
Future<void> startSession() async {
  await ProfileStorage.load();
  await SettingsStore.instance.load(uid: AuthService.uid);
  await AlarmService.instance.loadLimits();

  // A profile that still has the demo name shows the signed-in person's name.
  if (patientProfile.name.trim().isEmpty || patientProfile.name == 'John Doe') {
    patientProfile.name = AuthService.accountName;
    await ProfileStorage.save();
  }
  NotificationService.instance.requestPermission();
  currentUserName.value = AuthService.accountName;
  VitalsStore.instance.start();
  AlarmService.instance.init();
  // Connect to the ESP32 if an address is saved (otherwise demo data).
  DeviceService.instance.start();
  // Keep alarms and the device connection running with the screen off
  // (foreground service on Android, screen kept on elsewhere).
  await BackgroundMonitor.start();
}

/// After a successful login or sign-up: start the session and open Home.
Future<void> openApp(BuildContext context) async {
  await startSession();
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    appRoute<void>(const FeatureSelectionPage()),
    (_) => false,
  );
}
