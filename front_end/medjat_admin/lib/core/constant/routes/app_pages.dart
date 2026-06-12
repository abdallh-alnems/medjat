import 'package:get/get.dart';
import '../../class/crud.dart';
import 'app_routes.dart';
import '../theme/app_spacing.dart';
import '../../services/connectivity_service.dart';
import '../../services/dark_light_service.dart';
import '../../../data/data_source/remote/admin_auth_data/admin_auth_data.dart';
import '../../../data/data_source/remote/dashboard_data/dashboard_data.dart';
import '../../../data/data_source/remote/tenant_data/tenant_data.dart';
import '../../../data/data_source/remote/subscription_data/subscription_data.dart';
import '../../../data/data_source/remote/plan_data/plan_data.dart';
import '../../../data/data_source/remote/notification_data/notification_data.dart';
import '../../../data/data_source/remote/user_data/user_data.dart';
import '../../../data/data_source/remote/audit_data/audit_data.dart';
import '../../../data/data_source/remote/support_data/support_data.dart';
import '../../../data/data_source/remote/app_control_data/app_control_data.dart';
import '../../../data/data_source/remote/device_data/device_data.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/controller/dashboard/dashboard_controller.dart';
import '../../../logic/controller/tenant/tenant_controller.dart';
import '../../../logic/controller/subscription/subscription_controller.dart';
import '../../../logic/controller/plan/plan_controller.dart';
import '../../../logic/controller/notification/notification_controller.dart';
import '../../../logic/controller/user/user_controller.dart';
import '../../../logic/controller/audit/audit_controller.dart';
import '../../../logic/controller/support/support_controller.dart';
import '../../../logic/controller/app_control/app_control_controller.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../view/screen/splash/splash_screen.dart';
import '../../../view/screen/auth/login_screen.dart';
import '../../../view/screen/dashboard/dashboard_screen.dart';
import '../../../view/screen/tenants/tenants_screen.dart';
import '../../../view/screen/subscriptions/subscriptions_screen.dart';
import '../../../view/screen/plans/plans_screen.dart';
import '../../../view/screen/users/users_screen.dart';
import '../../../view/screen/audit/audit_screen.dart';
import '../../../view/screen/notifications/notifications_screen.dart';
import '../../../view/screen/support/support_inbox_screen.dart';
import '../../../view/screen/support/support_thread_screen.dart';
import '../../../view/screen/app_control/app_control_screen.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CRUD>(() => CRUD());
    Get.lazyPut<AdminAuthData>(() => AdminAuthData());
    Get.lazyPut<DeviceData>(() => DeviceData());
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    Get.put<DarkLightService>(DarkLightService(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<PushNotificationService>(PushNotificationService(), permanent: true);
  }
}

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardData>(() => DashboardData());
    Get.lazyPut<DashboardController>(() => DashboardController());
  }
}

class TenantsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TenantData>(() => TenantData());
    Get.lazyPut<TenantController>(() => TenantController());
  }
}

class SubscriptionsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SubscriptionData>(() => SubscriptionData());
    Get.lazyPut<SubscriptionController>(() => SubscriptionController());
  }
}

class PlansBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PlanData>(() => PlanData());
    Get.lazyPut<PlanController>(() => PlanController());
  }
}

class UsersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UserData>(() => UserData());
    Get.lazyPut<UserController>(() => UserController());
  }
}

class AuditBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuditData>(() => AuditData());
    Get.lazyPut<AuditController>(() => AuditController());
  }
}

class NotificationsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<NotificationData>(() => NotificationData());
    Get.lazyPut<NotificationController>(() => NotificationController());
  }
}

class SupportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SupportData>(() => SupportData());
    Get.lazyPut<SupportController>(() => SupportController());
  }
}

class AppControlBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AppControlData>(() => AppControlData());
    Get.lazyPut<AppControlController>(() => AppControlController());
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
    name: AppRoutes.home,
    page: () => const DashboardScreen(),
    binding: HomeBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.tenants,
    page: () => const TenantsScreen(),
    binding: TenantsBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.subscriptions,
    page: () => const SubscriptionsScreen(),
    binding: SubscriptionsBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.plans,
    page: () => const PlansScreen(),
    binding: PlansBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.users,
    page: () => const UsersScreen(),
    binding: UsersBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.audit,
    page: () => const AuditScreen(),
    binding: AuditBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.notifications,
    page: () => const NotificationsScreen(),
    binding: NotificationsBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.supportInbox,
    page: () => const SupportInboxScreen(),
    binding: SupportBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.supportThread,
    page: () => const SupportThreadScreen(),
    binding: SupportBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.appControl,
    page: () => const AppControlScreen(),
    binding: AppControlBinding(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
];
