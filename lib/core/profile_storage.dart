import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'auth_service.dart';

/// Saves the patient profile on the device, separately for each account,
/// so it is still there after the app is closed and opened again.
class ProfileStorage {
  ProfileStorage._();

  static String? get _key {
    final uid = AuthService.uid;
    return uid.isEmpty ? null : 'patient_profile_$uid';
  }

  /// Loads the signed-in account's profile (defaults if none saved yet).
  static Future<void> load() async {
    patientProfile.reset();
    final key = _key;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(key);
      if (text == null) return;
      final data = jsonDecode(text);
      if (data is Map<String, dynamic>) patientProfile.applyJson(data);
    } catch (_) {
      // Unreadable data: keep the defaults.
    }
  }

  static Future<void> save() async {
    final key = _key;
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(patientProfile.toJson()));
    } catch (_) {
      // Saving is best-effort; the app keeps working with in-memory data.
    }
  }
}
