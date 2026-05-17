import 'package:flutter/material.dart';
import '../../../core/constant/theme/theme.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          _ReportCard(
            icon: Icons.access_time_outlined,
            title: 'تقرير الحضور',
            subtitle: 'ملخص الحضور والانصراف والتأخير',
            color: colors.brand,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.s3),
          _ReportCard(
            icon: Icons.payments_outlined,
            title: 'تقرير الرواتب',
            subtitle: 'كشوف الرواتب والخصومات',
            color: colors.accentWarm,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.s3),
          _ReportCard(
            icon: Icons.group_outlined,
            title: 'تقرير الموظفين',
            subtitle: 'بيانات وإحصائيات الموظفين',
            color: colors.success,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.s3),
          _ReportCard(
            icon: Icons.beach_access_outlined,
            title: 'تقرير الإجازات',
            subtitle: 'ملخص الإجازات والغياب المحول',
            color: colors.warning,
            onTap: () {},
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
