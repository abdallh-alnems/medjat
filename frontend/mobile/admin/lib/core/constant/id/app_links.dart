import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppLinks {
  AppLinks._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  // Auth
  static String get adminLogin => '$base/v1/admin/auth/login';
  static String get adminLogout => '$base/v1/admin/auth/logout';
  static String get adminMe => '$base/v1/admin/auth/me';
  static String get adminChangePassword => '$base/v1/admin/auth/password';

  // Tenants
  static String get tenants => '$base/v1/admin/tenants';
  static String get tenantCreate => '$base/v1/admin/tenants';
  static String tenantUpdate(int tenantId) => '\$base/v1/admin/tenants/\$tenantId';
  static String get tenantDetail => '$base/v1/admin/tenants/detail';
  static String get tenantDiagnostics => '$base/v1/admin/tenants/diagnostics';
  static String get tenantActivate => '$base/v1/admin/tenants/activate';
  static String get tenantDeactivate => '$base/v1/admin/tenants/deactivate';

  // Acting on behalf of a client company
  static String get companyAdminSetActive => '$base/v1/admin/company-admins/set-active';
  static String get companyAdminResetPassword => '$base/v1/admin/company-admins/reset-password';
  static String get companyAdminInvite => '$base/v1/admin/company-admins/invite';
  static String get companyAdminImpersonate => '$base/v1/admin/company-admins/impersonate';

  // Dashboard
  static String get dashboardOverview => '$base/v1/admin/dashboard';

  // Notifications
  static String get notificationSendAll => '$base/v1/admin/announcements/all';
  static String get notificationSendTenant => '$base/v1/admin/announcements/tenant';

  // Company administrators (the client contact book) + our own audit trail
  static String get users => '$base/v1/admin/company-admins';
  static String get userCreate => '$base/v1/admin/operators';
  static String get auditLog => '$base/v1/admin/audit';

  // Support
  static String get supportList => '$base/v1/admin/support/tickets';
  static String get supportMessages => '$base/v1/admin/support/messages';
  static String get supportReply => '$base/v1/admin/support/reply';
  static String get supportStatus => '$base/v1/admin/support/status';
  static String supportAttachment(int messageId) =>
      '$base/v1/admin/support/attachment?message_id=$messageId';

  // App Control
  static String get appControlGet => '$base/v1/admin/app-control';
  static String get appControlSet => '$base/v1/admin/app-control';

  // Device Registration
  static String get deviceRegister => '$base/v1/admin/devices';
}
