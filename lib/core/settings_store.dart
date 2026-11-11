import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';

enum TempUnit { celsius, fahrenheit }

/// App-wide user settings. They are saved on the device (shared_preferences)
/// and loaded again when the app starts.
class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  // ----- Alarm sound -----
  bool soundEnabled = true;
  double volume = 0.8; // 0.0 – 1.0
  bool vibrationEnabled = true;

  /// Show a notification for new alarms while the app is in the background.
  bool notificationsEnabled = true;

  // ----- Display -----
  /// ECG sweep speed in mm/s (12.5, 25 or 50).
  double waveformSpeed = 25;
  TempUnit tempUnit = TempUnit.celsius;

  // ----- Device connection (used when the ESP32 is connected) -----
  String deviceHost = '';
  int devicePort = 81;
  bool deviceConnected = false;

  static const List<double> waveformSpeeds = [12.5, 25, 50];

  void setSoundEnabled(bool value) {
    soundEnabled = value;
    notifyListeners();
    save();
  }

  void setVolume(double value) {
    volume = value.clamp(0.0, 1.0).toDouble();
    notifyListeners();
    save();
  }

  void setNotifications(bool value) {
    notificationsEnabled = value;
    notifyListeners();
    save();
  }

  void setDarkMode(bool value) {
    darkMode.value = value;
    save();
  }

  void setArabic(bool value) {
    isArabic.value = value;
    save();
  }

  void setVibration(bool value) {
    vibrationEnabled = value;
    notifyListeners();
    save();
  }

  void setWaveformSpeed(double value) {
    waveformSpeed = value;
    notifyListeners();
    save();
  }

  void setTempUnit(TempUnit value) {
    tempUnit = value;
    notifyListeners();
    save();
  }

  void setDeviceConnected(bool value) {
    if (deviceConnected == value) return;
    deviceConnected = value;
    notifyListeners();
  }

  void setDevice(String host, int port) {
    deviceHost = host.trim();
    devicePort = port;
    notifyListeners();
    save();
  }

  // ----- Saving / loading -----

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      soundEnabled = p.getBool('s_sound') ?? soundEnabled;
      volume = p.getDouble('s_volume') ?? volume;
      vibrationEnabled = p.getBool('s_vibration') ?? vibrationEnabled;
      notificationsEnabled = p.getBool('s_notif') ?? notificationsEnabled;
      waveformSpeed = p.getDouble('s_speed') ?? waveformSpeed;
      tempUnit = p.getString('s_unit') == 'f'
          ? TempUnit.fahrenheit
          : TempUnit.celsius;
      deviceHost = p.getString('s_host') ?? deviceHost;
      devicePort = p.getInt('s_port') ?? devicePort;
      darkMode.value = p.getBool('s_dark') ?? true;
      isArabic.value = p.getBool('s_arabic') ?? false;
    } catch (_) {
      // Keep the defaults if the saved settings cannot be read.
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('s_sound', soundEnabled);
      await p.setDouble('s_volume', volume);
      await p.setBool('s_vibration', vibrationEnabled);
      await p.setBool('s_notif', notificationsEnabled);
      await p.setDouble('s_speed', waveformSpeed);
      await p.setString('s_unit', tempUnit == TempUnit.fahrenheit ? 'f' : 'c');
      await p.setString('s_host', deviceHost);
      await p.setInt('s_port', devicePort);
      await p.setBool('s_dark', darkMode.value);
      await p.setBool('s_arabic', isArabic.value);
    } catch (_) {
      // Saving is best-effort.
    }
  }

  // ----- Temperature helpers (values are always stored in °C) -----

  String get tempSymbol => tempUnit == TempUnit.celsius ? '°C' : '°F';

  double toDisplayTemp(double celsius) =>
      tempUnit == TempUnit.celsius ? celsius : celsius * 9 / 5 + 32;

  double fromDisplayTemp(double shown) =>
      tempUnit == TempUnit.celsius ? shown : (shown - 32) * 5 / 9;
}
