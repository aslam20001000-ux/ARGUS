import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'auth_service.dart';

enum TempUnit { celsius, fahrenheit }

/// User settings, saved on the device (shared_preferences) separately for
/// each account and loaded again when that account signs in.
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
  //
  // Each account keeps its own settings ("u_<uid>_..."). A copy is also kept
  // without the account ("s_..."), so the login screen opens with the theme
  // and language that were used last on this phone.

  static String _key(String uid, String name) =>
      uid.isEmpty ? 's_$name' : 'u_${uid}_$name';

  /// Loads the settings: the phone's last settings when [uid] is empty (app
  /// start), or the account's own settings after login. An account with no
  /// saved settings keeps the current ones, except the device address, which
  /// belongs to each person.
  Future<void> load({String uid = ''}) async {
    try {
      final p = await SharedPreferences.getInstance();
      String k(String name) => _key(uid, name);
      soundEnabled = p.getBool(k('sound')) ?? soundEnabled;
      volume = p.getDouble(k('volume')) ?? volume;
      vibrationEnabled = p.getBool(k('vibration')) ?? vibrationEnabled;
      notificationsEnabled = p.getBool(k('notif')) ?? notificationsEnabled;
      waveformSpeed = p.getDouble(k('speed')) ?? waveformSpeed;
      final unit = p.getString(k('unit'));
      if (unit != null) {
        tempUnit = unit == 'f' ? TempUnit.fahrenheit : TempUnit.celsius;
      }
      if (uid.isEmpty) {
        deviceHost = '';
        devicePort = 81;
      } else {
        deviceHost = p.getString(k('host')) ?? '';
        devicePort = p.getInt(k('port')) ?? 81;
      }
      darkMode.value = p.getBool(k('dark')) ?? darkMode.value;
      isArabic.value = p.getBool(k('arabic')) ?? isArabic.value;
    } catch (_) {
      // Keep the current values if the saved settings cannot be read.
    }
    notifyListeners();
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      final uid = AuthService.uid;
      for (final id in {'', uid}) {
        String k(String name) => _key(id, name);
        await p.setBool(k('sound'), soundEnabled);
        await p.setDouble(k('volume'), volume);
        await p.setBool(k('vibration'), vibrationEnabled);
        await p.setBool(k('notif'), notificationsEnabled);
        await p.setDouble(k('speed'), waveformSpeed);
        await p.setString(
          k('unit'),
          tempUnit == TempUnit.fahrenheit ? 'f' : 'c',
        );
        // The device address is personal: only saved for the account.
        if (id.isNotEmpty) {
          await p.setString(k('host'), deviceHost);
          await p.setInt(k('port'), devicePort);
        }
        await p.setBool(k('dark'), darkMode.value);
        await p.setBool(k('arabic'), isArabic.value);
      }
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
