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
import '../../../data/data_source/remote/break_data/break_data.dart';
import '../../../data/data_source/remote/notification_data/notification_data.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/bindings/home_binding.dart';
import '../../../logic/bindings/attendance_binding.dart';
import '../../../view/screen/auth/login_screen.dart';
import '../../../view/screen/auth/join_scan_screen.dart';
import '../../services/deep_link_service.dart';
import '../../../view/screen/splash/splash_screen.dart';
import '../../../view/screen/home/home_screen.dart';
import '../../../view/screen/attendance/scan_qr_screen.dart';
import '../../../view/screen/attendance/attendance_success_screen.dart';
import '../../../view/screen/profile/my_profile_screen.dart';
import '../../../view/screen/documents/my_documents_screen.dart';
import '../../../view/screen/payroll/payroll_screen.dart';
import '../../../view/screen/leave/leave_screen.dart';
import '../../../view/screen/break/break_screen.dart';
import '../../../view/screen/notifications/notifications_screen.dart';
import '../../../view/screen/settings/settings_screen.dart';
import '../../../view/screen/kiosk/kiosk_pair_screen.dart';
import '../../../view/screen/kiosk/kiosk_home_screen.dart';
import '../../../view/screen/kiosk/kiosk_face_checkin_screen.dart';
import '../../../view/screen/kiosk/kiosk_qr_checkin_screen.dart';
import '../../../view/screen/kiosk/kiosk_settings_screen.dart';
import '../../../view/screen/station/my_station_qr_screen.dart';
import '../../../logic/bindings/station_binding.dart';
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
    // fenix: recreate on demand — LeaveController is route-scoped and disposing
    // it would otherwise drop LeaveData, breaking a second visit to /leaves.
    Get.lazyPut<LeaveData>(() => LeaveData(), fenix: true);
    Get.lazyPut<BreakData>(() => BreakData(), fenix: true);
    Get.lazyPut<NotificationData>(() => NotificationData());
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    Get.put<LocationService>(LocationService(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.putAsync<DeepLinkService>(() => DeepLinkService().init());
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
    page: () => Scaffold(body: Center(child: Text('update_required'.tr))),
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
    name: AppRoutes.joinScan,
    page: () => const JoinScanScreen(),
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
    name: AppRoutes.breaks,
    page: () => const BreakScreen(),
  ),
  GetPage(
    name: AppRoutes.notifications,
    page: () => const NotificationsScreen(),
  ),
  GetPage(
    name: AppRoutes.settings,
    page: () => const SettingsScreen(),
  ),
  GetPage(
    name: AppRoutes.kioskPair,
    page: () => const KioskPairScreen(),
    binding: StationBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.kioskHome,
    page: () => const KioskHomeScreen(),
    binding: StationBinding(),
  ),
  GetPage(
    name: AppRoutes.kioskFaceCheckIn,
    page: () => const KioskFaceCheckInScreen(),
    binding: StationBinding(),
  ),
  GetPage(
    name: AppRoutes.kioskQrCheckIn,
    page: () => const KioskQrCheckInScreen(),
    binding: StationBinding(),
  ),
  GetPage(
    name: AppRoutes.kioskSettings,
    page: () => const KioskSettingsScreen(),
    binding: StationBinding(),
  ),
  GetPage(
    name: AppRoutes.myStationQr,
    page: () => const MyStationQrScreen(),
    binding: StationBinding(),
  ),
];
