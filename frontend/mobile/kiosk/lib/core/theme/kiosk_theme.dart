import 'package:flutter/material.dart';

/// Theme for a device nobody holds.
///
/// A kiosk is read from one to three metres away, often by someone who is
/// tired, in a queue, and not wearing their glasses. Every size here is larger
/// than a phone app would use and every target is bigger than a thumb needs —
/// that is the whole design brief, and it is why this is not simply a copy of
/// permedjat_app's theme.
class KioskTheme {
  KioskTheme._();

  /// The Permedjat brand colour, shared across every product. Never substitute a
  /// blue here — the palette was unified on this teal deliberately.
  static const Color brand = Color(0xFF0E7C86);
  static const Color brandDark = Color(0xFF4FC6CC);

  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFB45309);
  static const Color danger = Color(0xFFB91C1C);

  /// Minimum touch target. Well above the 48dp guideline: a worker with wet or
  /// gloved hands is the normal case at a factory door, not an edge case.
  static const double touchTarget = 72;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: brand);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFB),
      fontFamily: 'IBMPlexSansArabic',
      textTheme: _textTheme(const Color(0xFF0F172A)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(touchTarget),
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(touchTarget),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  /// Dark is not a user preference here — a kiosk has no settings an employee
  /// can reach. It exists because some branches mount tablets in dim corridors
  /// where a white screen is the brightest object in the room.
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandDark,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0B1120),
      fontFamily: 'IBMPlexSansArabic',
      textTheme: _textTheme(const Color(0xFFE2E8F0)),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(touchTarget),
          textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color onSurface) => TextTheme(
        // Used for the resolved employee's name — the single most important
        // string on the device, and the one a person confirms or rejects.
        displayMedium: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyLarge: TextStyle(fontSize: 22, color: onSurface),
        bodyMedium: TextStyle(fontSize: 20, color: onSurface),
      );
}
