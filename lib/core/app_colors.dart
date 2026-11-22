import 'package:flutter/material.dart';

import 'app_state.dart';

/// Colors that change between the dark and the light theme.
///
/// The accents are bright "neon" tones on the dark theme and deeper, more
/// saturated tones on the light theme so text and icons stay readable on
/// white.
class AppColors {
  AppColors._();

  static bool get dark => darkMode.value;

  // ----------------------------------------------------------- surfaces
  static Color get bg =>
      dark ? const Color(0xFF07111F) : const Color(0xFFF1F5FA);
  static Color get card =>
      dark ? const Color(0xFF0D1D30) : const Color(0xFFFFFFFF);
  static Color get cardAlt =>
      dark ? const Color(0xFF102B46) : const Color(0xFFE8F1FC);
  static Color get nav =>
      dark ? const Color(0xFF0B1929) : const Color(0xFFFFFFFF);
  static Color get chip =>
      dark ? const Color(0xFF10243A) : const Color(0xFFEEF3F9);
  static Color get chipStrong =>
      dark ? const Color(0xFF19334D) : const Color(0xFFDDE7F3);
  static Color get ecgBg =>
      dark ? const Color(0xFF071827) : const Color(0xFFF8FBFE);
  static Color get alarmCard =>
      dark ? const Color(0xFF2A1620) : const Color(0xFFFFECEF);
  static Color get greenSoft =>
      dark ? const Color(0xFF123323) : const Color(0xFFE2F6EC);

  /// Main text / icon color (white on dark, navy on light).
  static Color get text => dark ? Colors.white : const Color(0xFF0B1B2E);

  /// Thin outline around cards.
  static Color get border => dark
      ? Colors.white.withValues(alpha: .06)
      : const Color(0xFF0B1B2E).withValues(alpha: .08);

  /// Soft drop shadow for cards (none on the dark theme).
  static List<BoxShadow> get cardShadow => dark
      ? const []
      : [
          BoxShadow(
            color: const Color(0xFF1B3A5C).withValues(alpha: .07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF1B3A5C).withValues(alpha: .04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ];

  /// Background of the big header / hero cards.
  static List<Color> get heroGradient => dark
      ? const [Color(0xFF123A66), Color(0xFF0B2546), Color(0xFF0A1B33)]
      : const [Color(0xFF3B8CF0), Color(0xFF2468D6), Color(0xFF1C4FB0)];

  /// Inside of the avatar circle on a hero card.
  static List<Color> get heroAvatar => dark
      ? const [Color(0xFF1C4C7E), Color(0xFF0E2744)]
      : const [Color(0xFF5CA6F7), Color(0xFF2F72DA)];

  /// Ring around the avatar on a hero card.
  static List<Color> get heroRing => dark
      ? const [Color(0xFF4FD8E8), Color(0xFF54A9FF), Color(0xFF9B8CFF),
          Color(0xFF4FD8E8)]
      : const [Color(0xFFFFFFFF), Color(0xFFBFE0FF), Color(0xFFFFFFFF),
          Color(0xFFBFE0FF), Color(0xFFFFFFFF)];

  /// Darkest hero color (used as the border of the "online" dot).
  static Color get heroEdge => heroGradient[1];

  // ------------------------------------------------------------ accents
  static Color get blue =>
      dark ? const Color(0xFF54A9FF) : const Color(0xFF1F74E0);
  static Color get cyan =>
      dark ? const Color(0xFF4FD8E8) : const Color(0xFF0A9BB0);
  static Color get green =>
      dark ? const Color(0xFF38E08F) : const Color(0xFF12A15E);
  static Color get amber =>
      dark ? const Color(0xFFFFB547) : const Color(0xFFD9840A);
  static Color get orange =>
      dark ? const Color(0xFFFF8A65) : const Color(0xFFE5603A);
  static Color get red =>
      dark ? const Color(0xFFE65F72) : const Color(0xFFD63A52);
  static Color get violet =>
      dark ? const Color(0xFF9B8CFF) : const Color(0xFF6E56E0);
}
