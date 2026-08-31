import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/constant/routes/app_routes.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('reports'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          _ReportCard(
            icon: Icons.access_time_outlined,
            title: 'attendance_report'.tr,
            subtitle: 'attendance_summary'.tr,
            color: colors.brand,
            onTap: () => Get.toNamed<void>(AppRoutes.reportAttendance),
          ),
          const SizedBox(height: AppSpacing.s3),
          _ReportCard(
            icon: Icons.timelapse_outlined,
            title: 'overtime_late_report'.tr,
            subtitle: 'overtime_late_subtitle'.tr,
            color: colors.accentWarm,
            onTap: () => Get.toNamed<void>(AppRoutes.reportOvertimeLate),
          ),
          const SizedBox(height: AppSpacing.s3),
          _ReportCard(
            icon: Icons.payments_outlined,
            title: 'payroll_report'.tr,
            subtitle: 'payroll_statements'.tr,
            color: colors.accentWarm,
            onTap: () => Get.toNamed<void>(AppRoutes.reportPayroll),
          ),
          const SizedBox(height: AppSpacing.s3),
          _ReportCard(
            icon: Icons.group_outlined,
            title: 'employees_report'.tr,
            subtitle: 'employees_stats'.tr,
            color: colors.success,
            onTap: () => Get.toNamed<void>(AppRoutes.reportEmployees),
          ),
          const SizedBox(height: AppSpacing.s3),
          _ReportCard(
            icon: Icons.beach_access_outlined,
            title: 'leaves_report'.tr,
            subtitle: 'leaves_summary'.tr,
            color: colors.warning,
            onTap: () => Get.toNamed<void>(AppRoutes.reportLeaves),
          ),
          const SizedBox(height: AppSpacing.s3),
          _ReportCard(
            icon: Icons.description_outlined,
            title: 'documents_report'.tr,
            subtitle: 'documents_report_subtitle'.tr,
            color: colors.error,
            onTap: () => Get.toNamed<void>(AppRoutes.documentsReport),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ReportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.sm(context),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
