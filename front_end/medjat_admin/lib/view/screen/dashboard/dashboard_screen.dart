import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/dashboard/dashboard_controller.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: GetBuilder<AuthController>(
          builder: (c) => Text('مرحباً، ${c.admin?.displayNameOrUsername ?? ''}'),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'logout':
                  Get.find<AuthController>().logout();
                  break;
              }
            },
            itemBuilder: (context) {
              return [
                const PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
              ];
            },
          ),
        ],
      ),
      body: GetBuilder<DashboardController>(
        builder: (controller) {
          return RefreshIndicator(
            onRefresh: () => controller.loadDashboard(),
            color: colors.brand,
            child: HandlingDataRequest(
              statusRequest: controller.status.value,
              onRetry: () => controller.loadDashboard(),
              widget: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                children: [
                  const SizedBox(height: AppSpacing.s5),
                  Text('نظرة عامة', style: AppTextStyles.h2(context)),
                  const SizedBox(height: AppSpacing.s5),
                  _StatGrid(dashboard: controller.dashboard),
                  const SizedBox(height: AppSpacing.s7),
                  _buildQuickActions(context, colors),
                  const SizedBox(height: AppSpacing.s9),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AppColorScheme colors) {
    final admin = Get.find<AuthController>().admin;
    final isSuperAdmin = admin?.isSuperAdmin ?? false;
    // Sending an announcement needs `admin` on the backend; a readonly account
    // seeing the entry only earns a 403 that reads as "an error occurred".
    final canWrite = admin?.canWrite ?? false;
    final actions = [
      _QuickAction(icon: Icons.business, label: 'الشركات', route: AppRoutes.tenants),
      _QuickAction(icon: Icons.people, label: 'مديرو الشركات', route: AppRoutes.users),
      _QuickAction(icon: Icons.history, label: 'سجل العمليات', route: AppRoutes.audit),
      if (canWrite)
        _QuickAction(icon: Icons.notifications, label: 'الإشعارات', route: AppRoutes.notifications),
      if (canWrite)
        _QuickAction(icon: Icons.headset_mic, label: 'الدعم الفني', route: AppRoutes.supportInbox),
      _QuickAction(icon: Icons.account_circle, label: 'حسابي', route: AppRoutes.account),
      if (isSuperAdmin)
        _QuickAction(icon: Icons.person_add_alt_1, label: 'إضافة مشرف', route: AppRoutes.addAdmin),
      if (isSuperAdmin)
        _QuickAction(icon: Icons.settings_applications, label: 'التحكم بالتطبيقات', route: AppRoutes.appControl),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('الوصول السريع', style: AppTextStyles.h3(context)),
        const SizedBox(height: AppSpacing.s4),
        ...actions.map((action) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(action.icon, color: colors.brand),
              title: Text(
                action.label,
                style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 16),
              ),
              trailing: Icon(Icons.chevron_left, color: colors.textTertiary),
              onTap: () => Get.toNamed<void>(action.route),
            )),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  final dynamic dashboard;

  const _StatGrid({this.dashboard});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    final stats = [
      _StatItem(label: 'إجمالي الشركات', value: '${dashboard?.totalTenants ?? 0}'),
      _StatItem(label: 'شركات نشطة', value: '${dashboard?.activeTenants ?? 0}', color: colors.success),
      _StatItem(label: 'إجمالي المستخدمين', value: '${dashboard?.totalUsers ?? 0}'),
      _StatItem(label: 'إجمالي الموظفين', value: '${dashboard?.totalEmployees ?? 0}'),
    ];

    return Column(
      children: stats
          .map((stat) => Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.s3),
                padding: const EdgeInsets.all(AppSpacing.s4),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.borderHairline),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: colors.surface,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stat.label,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 15,
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      stat.value,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: stat.color ?? colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final Color? color;

  _StatItem({required this.label, required this.value, this.color});
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String route;

  _QuickAction({required this.icon, required this.label, required this.route});
}
