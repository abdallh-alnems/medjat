import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  static const double s1 = 4.0;
  static const double s2 = 8.0;
  static const double s3 = 12.0;
  static const double s4 = 16.0;
  static const double s5 = 24.0;
  static const double s6 = 32.0;
  static const double s7 = 48.0;
  static const double s8 = 64.0;
  static const double s9 = 96.0;
}

class AppRadius {
  AppRadius._();

  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 16.0;
  static const double full = 999.0;
}

class AppMotion {
  AppMotion._();

  static const Duration micro = Duration(milliseconds: 200);
  static const Duration transition = Duration(milliseconds: 320);
  static const Curve easing = Curves.easeOutQuart;
}
