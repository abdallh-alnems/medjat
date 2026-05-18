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

  // Subscriptions
  static String get subscriptions => '$base/admin/subscriptions/list.php';
  static String get subscriptionUpdate => '$base/admin/subscriptions/update.php';

  // Plans
  static String get plans => '$base/admin/plans/list.php';
  static String get planCreate => '$base/admin/plans/create.php';
  static String get planUpdate => '$base/admin/plans/update.php';

  // Dashboard
  static String get dashboardOverview => '$base/admin/dashboard/overview.php';

  // Notifications
  static String get notificationSendAll => '$base/admin/notifications/send_all.php';
  static String get notificationSendTenant => '$base/admin/notifications/send_tenant.php';

  // Users + Audit
  static String get users => '$base/admin/users/list.php';
  static String get auditLog => '$base/admin/audit/list.php';

  // Force Update (DEPRECATED — table removed from schema)
  // The endpoint file still exists at admin/force_update/trigger.php but won't work.
  // Delete the data layer that references this getter when convenient.
  static String get forceUpdateTrigger => '$base/admin/force_update/trigger.php';
}
