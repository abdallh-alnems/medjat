import 'package:flutter/material.dart';
import '../../core/constant/theme/app_colors.dart';

Color statusColor(AppColorScheme colors, String status) {
  switch (status) {
    case 'approved':
      return colors.success;
    case 'rejected':
      return colors.error;
    case 'cancelled':
      return colors.textTertiary;
    default:
      return colors.warning;
  }
}
