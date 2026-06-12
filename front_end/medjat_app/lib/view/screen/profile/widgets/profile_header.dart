import 'package:flutter/material.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';

class ProfileHeader extends StatelessWidget {
  final String name;
  final String jobTitle;

  const ProfileHeader({
    super.key,
    required this.name,
    required this.jobTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.brand(context),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.h3(context)),
                const SizedBox(height: 2),
                Text(jobTitle, style: AppTextStyles.bodySecondary(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
