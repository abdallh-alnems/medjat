import 'package:flutter/material.dart';

class AppColorScheme {
  final Color canvas;
  final Color surface;
  final Color sunken;
  final Color borderHairline;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color brand;
  final Color brandHover;
  final Color brandSubtle;
  final Color accentWarm;
  final Color error;
  final Color warning;
  final Color success;

  const AppColorScheme({
    required this.canvas,
    required this.surface,
    required this.sunken,
    required this.borderHairline,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.brand,
    required this.brandHover,
    required this.brandSubtle,
    required this.accentWarm,
    required this.error,
    required this.warning,
    required this.success,
  });
}

class AppColors {
  AppColors._();

  static AppColorScheme of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light ? light : dark;
  }

  static Color brand(BuildContext context) => of(context).brand;
  static Color textPrimary(BuildContext context) => of(context).textPrimary;
  static Color textSecondary(BuildContext context) => of(context).textSecondary;
  static Color textTertiary(BuildContext context) => of(context).textTertiary;

  static const light = AppColorScheme(
    canvas: Color(0xFFF9FCFC),
    surface: Color(0xFFF2F7F7),
    sunken: Color(0xFFE6EEEF),
    borderHairline: Color(0xFFD0DCDD),
    borderStrong: Color(0xFFA8C0C2),
    textPrimary: Color(0xFF0F2B2D),
    textSecondary: Color(0xFF4A6B6D),
    textTertiary: Color(0xFF7A9B9D),
    brand: Color(0xFF0E7C86),
    brandHover: Color(0xFF0B5E63),
    brandSubtle: Color(0xFFD6EDEE),
    accentWarm: Color(0xFFB8860B),
    error: Color(0xFFC0392B),
    warning: Color(0xFFD4A017),
    success: Color(0xFF27AE60),
  );

  static const dark = AppColorScheme(
    canvas: Color(0xFF121F22),
    surface: Color(0xFF18272A),
    sunken: Color(0xFF0E1A1D),
    borderHairline: Color(0xFF2A3D40),
    borderStrong: Color(0xFF3D5558),
    textPrimary: Color(0xFFEEF5F5),
    textSecondary: Color(0xFFA4BFC1),
    textTertiary: Color(0xFF6E8F91),
    brand: Color(0xFF4FC6CC),
    brandHover: Color(0xFF6FD3D8),
    brandSubtle: Color(0xFF173C41),
    accentWarm: Color(0xFFD4A030),
    error: Color(0xFFE06050),
    warning: Color(0xFFE8C040),
    success: Color(0xFF50C890),
  );
}
