import 'package:get/get.dart';
import '../../class/crud.dart';
import 'app_routes.dart';
import '../theme/app_spacing.dart';
import '../../services/remote_config_service.dart';
import '../../widget/app_gate.dart';
import '../../../data/data_source/remote/auth_data/auth_data.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../view/screen/auth/login_screen.dart';
import '../../../view/screen/auth/forgot_password_screen.dart';
import '../../../view/screen/splash/splash_screen.dart';
import '../../../view/screen/home/home_screen.dart';
import '../../../view/screen/placeholder_screen.dart';
import '../../../core/shared/layout/tab_shell.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CRUD>(() => CRUD());
    Get.lazyPut<AuthData>(() => AuthData());
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<RemoteConfigService>(RemoteConfigService(), permanent: true);
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
    page: () => AppGate(
      child: TabShell(
        screens: [
          const HomeScreen(),
          const PlaceholderScreen(title: 'سجل حضوري'),
          const PlaceholderScreen(title: 'راتبي'),
          const PlaceholderScreen(title: 'حسابي'),
        ],
      ),
    ),
    binding: TabBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.scanQr,
    page: () => const PlaceholderScreen(title: 'مسح QR'),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.attendanceSuccess,
    page: () => const PlaceholderScreen(title: 'تم التسجيل'),
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
