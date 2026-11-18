import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps monitoring alive when the phone screen turns off.
///
/// * Android: starts MonitorService (android/app/src/main/kotlin/...), a
///   foreground service with an ongoing "ARGUS is monitoring" notification.
///   The alarm checks, the ESP32 connection and the alarm sound then keep
///   running in the background and with the screen off.
/// * iOS and others: there is no such service, so the screen is kept on
///   instead while monitoring.
class BackgroundMonitor {
  BackgroundMonitor._();

  static const MethodChannel _channel = MethodChannel('argus/monitor');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Call when a session starts (after login).
  static Future<void> start() async {
    try {
      if (_android) {
        await _channel.invokeMethod<bool>('start');
      } else {
        await WakelockPlus.enable();
      }
    } catch (e) {
      debugPrint('Background monitoring not started: $e');
      // Last resort: at least keep the screen on.
      try {
        await WakelockPlus.enable();
      } catch (_) {}
    }
  }

  /// Call on logout.
  static Future<void> stop() async {
    try {
      if (_android) await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}
