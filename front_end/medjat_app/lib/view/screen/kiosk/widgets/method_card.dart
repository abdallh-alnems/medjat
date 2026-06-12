import 'package:flutter/material.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';

class MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const MethodCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.brand(context).withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
          color: AppColors.brand(context).withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.brand(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: AppColors.brand(context)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.h3(context)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.bodySecondary(context)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppColors.brand(context)),
          ],
        ),
      ),
    );
  }
}
