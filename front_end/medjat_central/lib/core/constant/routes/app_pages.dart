import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../class/crud.dart';
import 'app_routes.dart';
import '../theme/theme.dart';
import '../../services/connectivity_service.dart';
import '../../../data/data_source/remote/auth_data/auth_data.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/settings/settings_controller.dart';
import '../../../logic/bindings/home_binding.dart';
import '../../../view/screen/auth/login_screen.dart';
import '../../../view/screen/splash/splash_screen.dart';
import '../../../view/screen/dashboard/dashboard_screen.dart';
import '../../../view/screen/employee/employees_screen.dart';
import '../../../view/screen/attendance/attendance_screen.dart';
import '../../../view/screen/payroll/payroll_screen.dart';
import '../../../view/screen/leave/leave_screen.dart';
import '../../../view/screen/branch/branch_screen.dart';
import '../../../view/screen/report/report_screen.dart';
import '../../../core/shared/layout/tab_shell.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CRUD>(() => CRUD());
    Get.lazyPut<AuthData>(() => AuthData());
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);
  }
}

List<GetPage> getPages = [
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
    name: AppRoutes.home,
    page: () => TabShell(
      screens: [
        const DashboardScreen(),
        const EmployeesScreen(),
        const AttendanceScreen(),
        const PayrollScreen(),
        const MoreScreen(),
      ],
    ),
    binding: HomeBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.leaveManage,
    page: () => const LeaveScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.branchManage,
    page: () => const BranchScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.reports,
    page: () => const ReportScreen(),
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
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        children: [
          if (auth.user?.canManageEmployees == true)
            _MenuTile(
              icon: Icons.groups_outlined,
              title: 'الإجازات',
              onTap: () => Get.toNamed(AppRoutes.leaveManage),
            ),
          if (auth.user?.canManageBranches == true)
            _MenuTile(
              icon: Icons.account_tree_outlined,
              title: 'الفروع',
              onTap: () => Get.toNamed(AppRoutes.branchManage),
            ),
          if (auth.user?.canViewReports == true)
            _MenuTile(
              icon: Icons.assessment_outlined,
              title: 'التقارير',
              onTap: () => Get.toNamed(AppRoutes.reports),
            ),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'الإعدادات',
            onTap: () {},
          ),
          const Divider(),
          _MenuTile(
            icon: Icons.logout,
            title: 'تسجيل الخروج',
            onTap: () => settingsCtrl.logout(),
            isDestructive: true,
          ),
        ],
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
