import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class CompanySettingsHubScreen extends StatelessWidget {
  const CompanySettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Scaffold(
      appBar: AppBar(title: Text('company_settings'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          _HubSectionHeader(title: 'company_data'.tr),
          _HubTile(
            icon: Icons.business_outlined,
            title: 'company_data'.tr,
            subtitle: 'edit_company_info'.tr,
            onTap: () => Get.toNamed<void>(AppRoutes.companySettings),
          ),
          const SizedBox(height: AppSpacing.s2),
          _HubTile(
            icon: Icons.tune_outlined,
            title: 'deduction_rules'.tr,
            subtitle: 'set_late_absence_rules'.tr,
            onTap: () => Get.toNamed<void>(AppRoutes.deductionRules),
          ),
          const SizedBox(height: AppSpacing.s2),
          _HubTile(
            icon: Icons.fact_check_outlined,
            title: 'attendance_method_title'.tr,
            subtitle: 'attendance_method_subtitle'.tr,
            onTap: () => Get.toNamed<void>(AppRoutes.attendanceMethod),
          ),
          const SizedBox(height: AppSpacing.s2),
          _HubTile(
            icon: Icons.event_available_outlined,
            title: 'leave_settings_title'.tr,
            subtitle: 'leave_settings_subtitle'.tr,
            onTap: () => Get.toNamed<void>(AppRoutes.leaveSettings),
          ),
          const SizedBox(height: AppSpacing.s2),
          _HubTile(
            icon: Icons.description_outlined,
            title: 'document_required_types'.tr,
            subtitle: 'document_required_types_subtitle'.tr,
            onTap: () => Get.toNamed<void>(AppRoutes.requiredDocuments),
          ),
          const SizedBox(height: AppSpacing.s2),
          _HubTile(
            icon: Icons.category_outlined,
            title: 'employee_categories'.tr,
            subtitle: 'employee_categories_subtitle'.tr,
            onTap: () => Get.toNamed<void>(AppRoutes.categories),
          ),
          const SizedBox(height: AppSpacing.s2),
          _HubTile(
            icon: Icons.group_add_outlined,
            title: 'team_and_permissions'.tr,
            subtitle: 'team_and_permissions_subtitle'.tr,
            onTap: () => Get.toNamed<void>(AppRoutes.team),
          ),
          if (auth.user?.canManageEmployees == true ||
              auth.user?.canManagePayroll == true ||
              auth.user?.canManageBranches == true) ...[
            const SizedBox(height: AppSpacing.s5),
            _HubSectionHeader(title: 'company_operations_structure'.tr),
            if (auth.user?.canManageEmployees == true) ...[
              _HubTile(
                icon: Icons.schedule_outlined,
                title: 'shifts'.tr,
                subtitle: 'shifts_subtitle'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.shifts),
              ),
              const SizedBox(height: AppSpacing.s2),
            ],
            if (auth.user?.canManagePayroll == true) ...[
              _HubTile(
                icon: Icons.upload_file_outlined,
                title: 'export_templates'.tr,
                subtitle: 'export_templates_subtitle'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.exportTemplates),
              ),
              const SizedBox(height: AppSpacing.s2),
            ],
            if (auth.user?.canManageBranches == true)
              _HubTile(
                icon: Icons.account_tree_outlined,
                title: 'branches'.tr,
                subtitle: 'branches_subtitle'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.branchManage),
              ),
          ],
        ],
      ),
    );
  }
}

class _HubSectionHeader extends StatelessWidget {
  final String title;
  const _HubSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s3),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.04,
          color: AppColors.of(context).textTertiary,
        ),
      ),
    );
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
            Icon(icon, size: 22, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.sm(context),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left
                  : Icons.chevron_right,
              size: 20,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
