import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../class/crud.dart';
import 'app_routes.dart';
import '../theme/theme.dart';
import '../../services/connectivity_service.dart';
import '../../services/dark_light_service.dart';
import '../../../data/data_source/remote/auth_data/auth_data.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/document_data/document_data.dart';
import '../../../data/data_source/remote/deduction_rule_data/deduction_rule_data.dart';
import '../../../data/data_source/remote/role_data/role_data.dart';
import '../../../data/data_source/remote/company_settings_data/company_settings_data.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/settings/settings_controller.dart';
import '../../../logic/bindings/home_binding.dart';
import '../../../view/screen/auth/login_screen.dart';
import '../../../view/screen/auth/signup_screen.dart';
import '../../../view/screen/auth/verify_email_screen.dart';
import '../../../view/screen/auth/forgot_password_screen.dart';
import '../../../view/screen/splash/splash_screen.dart';
import '../../../view/screen/onboarding/onboarding_screen.dart';
import '../../../view/screen/dashboard/dashboard_screen.dart';
import '../../../view/screen/employee/employees_screen.dart';
import '../../../view/screen/employee/add_employee_screen.dart';
import '../../../view/screen/employee/employee_detail_screen.dart';
import '../../../view/screen/attendance/attendance_screen.dart';
import '../../../view/screen/payroll/payroll_screen.dart';
import '../../../view/screen/leave/leave_screen.dart';
import '../../../view/screen/branch/branch_screen.dart';
import '../../../view/screen/report/report_screen.dart';
import '../../../view/screen/settings/deduction_rules_screen.dart';
import '../../../view/screen/settings/role_management_screen.dart';
import '../../../view/screen/settings/company_settings_screen.dart';
import '../../../core/shared/layout/tab_shell.dart';
import '../../middleware/auth_middleware.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CRUD>(() => CRUD());
    Get.lazyPut<AuthData>(() => AuthData());
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    Get.put<DarkLightService>(DarkLightService(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);
  }
}

List<GetPage<dynamic>> getPages = [
  GetPage(
    name: AppRoutes.splash,
    page: () => const SplashScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.login,
    page: () => LoginScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.signup,
    page: () => SignUpScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.verifyEmail,
    page: () => const VerifyEmailScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.forgotPassword,
    page: () => ForgotPasswordScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.onboarding,
    page: () => const OnboardingScreen(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.home,
    page: () => const TabShell(
      screens: [
        DashboardScreen(),
        EmployeesScreen(),
        AttendanceScreen(),
        PayrollScreen(),
        MoreScreen(),
      ],
    ),
    binding: HomeBinding(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.employeeAdd,
    page: () => const AddEmployeeScreen(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.employeeDetail,
    page: () => const EmployeeDetailScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<EmployeeData>(() => EmployeeData());
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<DocumentData>(() => DocumentData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.leaveManage,
    page: () => const LeaveScreen(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.branchManage,
    page: () => const BranchScreen(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.reports,
    page: () => const ReportScreen(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.deductionRules,
    page: () => const DeductionRulesScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<DeductionRuleData>(() => DeductionRuleData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.rolesManage,
    page: () => const RoleManagementScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<RoleData>(() => RoleData());
      Get.lazyPut<BranchData>(() => BranchData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.companySettings,
    page: () => const CompanySettingsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<CompanySettingsData>(() => CompanySettingsData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
];

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final settingsCtrl = Get.find<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: Text('more'.tr)),
      body: ListView(
        children: [
          if (auth.user?.canManageEmployees == true)
            _MenuTile(
              icon: Icons.groups_outlined,
              title: 'leaves'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.leaveManage),
            ),
          if (auth.user?.canManageBranches == true)
            _MenuTile(
              icon: Icons.account_tree_outlined,
              title: 'branches'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.branchManage),
            ),
          if (auth.user?.canViewReports == true)
            _MenuTile(
              icon: Icons.assessment_outlined,
              title: 'reports'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.reports),
            ),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'settings'.tr,
            onTap: () => _navigateToSettings(context),
          ),
          const Divider(),
          _MenuTile(
            icon: Icons.logout,
            title: 'logout'.tr,
            onTap: () => settingsCtrl.logout(),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _InlineSettingsScreen(),
      ),
    );
  }
}

class _InlineSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settingsCtrl = Get.find<SettingsController>();
    final auth = Get.find<AuthController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('settings'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          if (auth.user?.canManageBranches == true) ...[
            _SettingsSectionHeader(title: 'company'.tr),
            _SettingsTile(
              icon: Icons.tune_outlined,
              title: 'deduction_rules'.tr,
              subtitle: 'set_late_absence_rules'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.deductionRules),
            ),
            _SettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              title: 'role_management'.tr,
              subtitle: 'roles_users'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.rolesManage),
            ),
            _SettingsTile(
              icon: Icons.business_outlined,
              title: 'company_data'.tr,
              subtitle: 'edit_company_info'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.companySettings),
            ),
            const SizedBox(height: AppSpacing.s5),
          ],
          _SettingsSectionHeader(title: 'app'.tr),
          _SettingsTile(
            icon: Icons.dark_mode_outlined,
            title: 'dark_mode'.tr,
            subtitle: 'enable_dark_mode'.tr,
            trailing: Obx(() => Switch.adaptive(
                  value: settingsCtrl.isDark,
                  onChanged: (_) => settingsCtrl.toggleTheme(),
                )),
            onTap: () => settingsCtrl.toggleTheme(),
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'change_password'.tr,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.s5),
          _SettingsSectionHeader(title: 'account'.tr),
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s3),
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colors.brandSubtle,
                  child: Text(
                    (auth.user != null && auth.user!.name.isNotEmpty)
                        ? auth.user!.name[0]
                        : '?',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.brand,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.user?.name ?? 'admin'.tr,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        auth.user?.email ?? '',
                        style: AppTextStyles.sm(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Center(
            child: TextButton(
              onPressed: settingsCtrl.logout,
              style: TextButton.styleFrom(
                foregroundColor: colors.error,
              ),
              child: Text('logout'.tr),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  const _SettingsSectionHeader({required this.title});

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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s2),
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
            if (trailing != null)
              trailing!
            else
              Icon(Icons.chevron_left, size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? colors.error : colors.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDestructive ? colors.error : colors.textPrimary,
        ),
      ),
      trailing: Icon(Icons.chevron_left, color: colors.textTertiary),
      onTap: onTap,
    );
  }
}
