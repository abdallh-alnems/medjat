import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppLinks {
  AppLinks._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  static String get login => '$base/admin/auth/login';
  static String get logout => '$base/admin/auth/logout';
  static String get me => '$base/admin/me';
  static String get dashboard => '$base/admin/dashboard';
  static String get employees => '$base/admin/employees';
  static String employeeDetail(int id) => '$base/admin/employees/$id';
  static String get branches => '$base/admin/branches';
  static String branchDetail(int id) => '$base/admin/branches/$id';
  static String get attendance => '$base/admin/attendance';
  static String get attendanceManual => '$base/admin/attendance/manual';
  static String get payroll => '$base/admin/payroll';
  static String payrollMonth(int month, int year) =>
      '$base/admin/payroll/$month/$year';
  static String payrollApprove(int id) => '$base/admin/payroll/$id/approve';
  static String get leaves => '$base/admin/leaves';
  static String leaveApprove(int id) => '$base/admin/leaves/$id/approve';
  static String leaveReject(int id) => '$base/admin/leaves/$id/reject';
  static String get deductionRules => '$base/admin/deduction-rules';
  static String get reports => '$base/admin/reports';
  static String get reportAttendance => '$base/admin/reports/attendance';
  static String get reportPayroll => '$base/admin/reports/payroll';
  static String get roles => '$base/admin/roles';
  static String get companySettings => '$base/admin/company-settings';
  static String get notifications => '$base/admin/notifications';
  static String notificationRead(int id) =>
      '$base/admin/notifications/$id/read';
  static String get registerFcm => '$base/devices/register-fcm';
}
