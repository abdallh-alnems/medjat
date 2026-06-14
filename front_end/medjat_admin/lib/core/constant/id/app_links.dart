import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppLinks {
  AppLinks._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  // Auth
  static String get adminLogin => '$base/admin/auth/login.php';
  static String get adminLogout => '$base/admin/auth/logout.php';
  static String get adminMe => '$base/admin/auth/me.php';

  // Tenants
  static String get tenants => '$base/admin/tenants/list.php';
  static String get tenantCreate => '$base/admin/tenants/create.php';
  static String get tenantDetail => '$base/admin/tenants/detail.php';
  static String get tenantActivate => '$base/admin/tenants/activate.php';
  static String get tenantDeactivate => '$base/admin/tenants/deactivate.php';

  // Dashboard
  static String get dashboardOverview => '$base/admin/dashboard/overview.php';

  // Notifications
  static String get notificationSendAll => '$base/admin/notifications/send_all.php';
  static String get notificationSendTenant => '$base/admin/notifications/send_tenant.php';

  // Users + Audit
  static String get users => '$base/admin/users/list.php';
  static String get userCreate => '$base/admin/users/create.php';
  static String get auditLog => '$base/admin/audit/list.php';

  // Support
  static String get supportList => '$base/app/admin_support/list.php';
  static String get supportMessages => '$base/app/admin_support/messages.php';
  static String get supportReply => '$base/app/admin_support/reply.php';
  static String get supportStatus => '$base/app/admin_support/status.php';

  // App Control
  static String get appControlGet => '$base/app/admin_app_control/get.php';
  static String get appControlSet => '$base/app/admin_app_control/set.php';

  // Device Registration
  static String get deviceRegister => '$base/app/admin/devices/register.php';
}
