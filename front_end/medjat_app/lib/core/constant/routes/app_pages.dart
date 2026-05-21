import 'package:get/get.dart';
import '../../class/crud.dart';
import 'app_routes.dart';
import '../theme/app_spacing.dart';
import '../../services/update_service.dart';
import '../../package/rating_app.dart';
import '../../widget/maintenance_gate.dart';
import '../../widget/update_gate.dart';
import '../../../data/data_source/remote/auth_data/auth_data.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/bindings/home_binding.dart';
import '../../../logic/bindings/attendance_binding.dart';
import '../../../view/screen/auth/login_screen.dart';
import '../../../view/screen/auth/forgot_password_screen.dart';
import '../../../view/screen/splash/splash_screen.dart';
import '../../../view/screen/home/home_screen.dart';
import '../../../view/screen/attendance/scan_qr_screen.dart';
import '../../../view/screen/attendance/attendance_success_screen.dart';
import '../../../view/screen/placeholder_screen.dart';
import '../../../core/shared/layout/tab_shell.dart';
import '../../services/connectivity_service.dart';
import '../../services/location_service.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CRUD>(() => CRUD());
    Get.lazyPut<AuthData>(() => AuthData());
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
    page: () => LoginScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.forgotPassword,
    page: () => const ForgotPasswordScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.forceUpdate,
    page: () => const PlaceholderScreen(title: 'تحديث مطلوب'),
  ),
  GetPage(
    name: AppRoutes.home,
    page: () => const MaintenanceGate(
      child: UpdateGate(
        child: TabShell(
          screens: [
            HomeScreen(),
            PlaceholderScreen(title: 'سجل حضوري'),
            PlaceholderScreen(title: 'راتبي'),
            PlaceholderScreen(title: 'حسابي'),
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
    name: AppRoutes.attendanceDetail,
    page: () => const PlaceholderScreen(title: 'تفاصيل اليوم'),
  ),
  GetPage(
    name: AppRoutes.payrollDetail,
    page: () => const PlaceholderScreen(title: 'تفاصيل الراتب'),
  ),
  GetPage(
    name: AppRoutes.myDocuments,
    page: () => const PlaceholderScreen(title: 'أوراقي'),
  ),
  GetPage(
    name: AppRoutes.documentViewer,
    page: () => const PlaceholderScreen(title: 'عرض الورقة'),
  ),
  GetPage(
    name: AppRoutes.settings,
    page: () => const PlaceholderScreen(title: 'الإعدادات'),
  ),
  GetPage(
    name: AppRoutes.changePassword,
    page: () => const PlaceholderScreen(title: 'تغيير كلمة السر'),
  ),
  GetPage(
    name: AppRoutes.notifications,
    page: () => const PlaceholderScreen(title: 'الإشعارات'),
  ),
  GetPage(
    name: AppRoutes.about,
    page: () => const PlaceholderScreen(title: 'عن التطبيق'),
  ),
  GetPage(
    name: AppRoutes.myProfile,
    page: () => const PlaceholderScreen(title: 'بياناتي'),
  ),
];
