import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/constant/theme/app_text_styles.dart';

/// Bottom sheet shown when a branch enables more than one self check-in
/// method (qr_gps + gps_only). Lets the employee pick which one to use.
class AttendanceMethodPickerSheet extends StatelessWidget {
  final List<String> methods;
  final ValueChanged<String> onSelected;

  const AttendanceMethodPickerSheet({
    super.key,
    required this.methods,
    required this.onSelected,
  });

  static void show({
    required List<String> methods,
    required ValueChanged<String> onSelected,
  }) {
    Get.bottomSheet<void>(
      AttendanceMethodPickerSheet(methods: methods, onSelected: onSelected),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.s3),
              decoration: BoxDecoration(
                color: colors.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('choose_attendance_method'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: AppSpacing.s4),
          for (final method in methods) ...[
            _MethodTile(
              colors: colors,
              icon: method == 'gps_only'
                  ? Icons.location_on_outlined
                  : Icons.qr_code_scanner,
              title: (method == 'gps_only' ? 'method_gps_only' : 'method_qr_gps')
                  .tr,
              description: (method == 'gps_only'
                      ? 'method_gps_only_desc'
                      : 'method_qr_gps_desc')
                  .tr,
              onTap: () {
                Get.back<void>();
                onSelected(method);
              },
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
          const SizedBox(height: AppSpacing.s2),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final AppColorScheme colors;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _MethodTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: colors.brand),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppTextStyles.arabicFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: AppTextStyles.arabicFamily,
                      fontSize: 11,
                      color: colors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
