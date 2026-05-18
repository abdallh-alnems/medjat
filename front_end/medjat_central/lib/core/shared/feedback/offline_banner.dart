import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constant/theme/app_colors.dart';
import '../../constant/theme/app_spacing.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      color: AppColors.light.warning.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 16,
            color: AppColors.light.warning,
          ),
          const SizedBox(width: AppSpacing.s2),
          Text(
            'offline'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.light.warning,
            ),
          ),
        ],
      ),
    );
  }
}
