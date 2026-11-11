import 'package:flutter/material.dart';

import 'app_state.dart';

/// Colors that change between the dark and the light theme.
/// (Blue / green / red accents stay the same in both.)
class AppColors {
  AppColors._();

  static bool get dark => darkMode.value;

  static Color get bg => dark ? const Color(0xFF07111F) : const Color(0xFFEFF4FA);
  static Color get card => dark ? const Color(0xFF0D1D30) : const Color(0xFFFFFFFF);
  static Color get cardAlt => dark ? const Color(0xFF102B46) : const Color(0xFFE3EEFA);
  static Color get nav => dark ? const Color(0xFF0B1929) : const Color(0xFFFFFFFF);
  static Color get chip => dark ? const Color(0xFF10243A) : const Color(0xFFE6EEF7);
  static Color get chipStrong => dark ? const Color(0xFF19334D) : const Color(0xFFD5E3F2);
  static Color get ecgBg => dark ? const Color(0xFF071827) : const Color(0xFFF7FAFD);
  static Color get alarmCard => dark ? const Color(0xFF2A1620) : const Color(0xFFFFE9ED);
  static Color get greenSoft => dark ? const Color(0xFF123323) : const Color(0xFFDDF6EA);

  /// Main text / icon color (white on dark, navy on light).
  static Color get text => dark ? Colors.white : const Color(0xFF0B1B2E);
}
