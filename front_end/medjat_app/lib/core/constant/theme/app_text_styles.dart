import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const String arabicFamily = 'IBM Plex Sans Arabic';
  static const String latinFamily = 'Geist';

  static TextStyle display(BuildContext context) => TextStyle(
        fontFamily: latinFamily,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.02,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle h1(BuildContext context) => TextStyle(
        fontFamily: arabicFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle h2(BuildContext context) => TextStyle(
        fontFamily: arabicFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle h3(BuildContext context) => TextStyle(
        fontFamily: arabicFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle body(BuildContext context) => TextStyle(
        fontFamily: arabicFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.55,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle bodySecondary(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return TextStyle(
      fontFamily: arabicFamily,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.55,
      color: isLight ? AppColors.light.textSecondary : AppColors.dark.textSecondary,
    );
  }

  static TextStyle sm(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return TextStyle(
      fontFamily: arabicFamily,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: isLight ? AppColors.light.textSecondary : AppColors.dark.textSecondary,
    );
  }

  static TextStyle xs(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return TextStyle(
      fontFamily: arabicFamily,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.5,
      letterSpacing: 0.04,
      color: isLight ? AppColors.light.textTertiary : AppColors.dark.textTertiary,
    );
  }

  static TextStyle tabular(BuildContext context) => TextStyle(
        fontFamily: latinFamily,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.02,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: Theme.of(context).colorScheme.onSurface,
      );
}
