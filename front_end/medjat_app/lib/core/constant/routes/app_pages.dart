import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../class/crud.dart';
import 'app_routes.dart';
import '../theme/app_spacing.dart';
import '../../services/update_service.dart';
import '../../package/rating_app.dart';
import '../../widget/maintenance_gate.dart';
import '../../widget/update_gate.dart';
import '../../../data/data_source/remote/auth_data/auth_data.dart';
import '../../../data/data_source/remote/profile_data/profile_data.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';
import '../../../data/data_source/remote/leave_data/leave_data.dart';
import '../../../data/data_source/remote/notification_data/notification_data.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/bindings/home_binding.dart';
import '../../../logic/bindings/attendance_binding.dart';
import '../../../view/screen/auth/login_screen.dart';
import '../../../view/screen/splash/splash_screen.dart';
import '../../../view/screen/home/home_screen.dart';
import '../../../view/screen/attendance/scan_qr_screen.dart';
import '../../../view/screen/attendance/attendance_success_screen.dart';
import '../../../view/screen/profile/my_profile_screen.dart';
import '../../../view/screen/documents/my_documents_screen.dart';
import '../../../view/screen/payroll/payroll_screen.dart';
import '../../../view/screen/leave/leave_screen.dart';
import '../../../view/screen/notifications/notifications_screen.dart';
import '../../../view/screen/settings/settings_screen.dart';
import '../../../core/shared/layout/tab_shell.dart';
import '../../services/connectivity_service.dart';
import '../../services/location_service.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CRUD>(() => CRUD());
    Get.lazyPut<AuthData>(() => AuthData());
    Get.lazyPut<ProfileData>(() => ProfileData());
    Get.lazyPut<PayrollData>(() => PayrollData());
    Get.lazyPut<LeaveData>(() => LeaveData());
    Get.lazyPut<NotificationData>(() => NotificationData());
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    Get.put<LocationService>(LocationService(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<UpdateService>(UpdateService(), permanent: true);
    Get.put<RateMyAppController>(RateMyAppController(), permanent: true);
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
    page: () => const LoginScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.forceUpdate,
    page: () => const Scaffold(body: Center(child: Text('تحديث مطلوب'))),
  ),
  GetPage(
    name: AppRoutes.home,
    page: () => const MaintenanceGate(
      child: UpdateGate(
        child: TabShell(
          screens: [
            HomeScreen(),
            MyProfileScreen(),
            PayrollScreen(),
            SettingsScreen(),
          ],
        ),
      ),
    ),
    binding: HomeBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.scanQr,
    page: () => const ScanQrScreen(),
    binding: AttendanceBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.attendanceSuccess,
    page: () => const AttendanceSuccessScreen(),
  ),
  GetPage(
    name: AppRoutes.myProfile,
    page: () => const MyProfileScreen(),
  ),
  GetPage(
    name: AppRoutes.myDocuments,
    page: () => const MyDocumentsScreen(),
  ),
  GetPage(
    name: AppRoutes.payroll,
    page: () => const PayrollScreen(),
  ),
  GetPage(
    name: AppRoutes.leaves,
    page: () => const LeaveScreen(),
  ),
  GetPage(
    name: AppRoutes.notifications,
    page: () => const NotificationsScreen(),
  ),
  GetPage(
    name: AppRoutes.settings,
    page: () => const SettingsScreen(),
  ),
];
