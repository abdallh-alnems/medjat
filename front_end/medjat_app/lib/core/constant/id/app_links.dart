import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppLinks {
  AppLinks._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  // ── Auth ───────────────────────────────────────────────
  static String get login => '$base/app/auth/login.php';
  static String get logout => '$base/app/auth/logout.php'; // TODO: backend endpoint missing
  static String get me => '$base/app/auth/login.php'; // login.php returns user info
  static String get today => '$base/app/attendance/get_my_attendance.php?today=1';
  static String get refresh => '$base/app/auth/refresh.php'; // TODO: backend endpoint missing
  static String get forgotPassword => '$base/app/auth/forgot_password.php'; // TODO: backend endpoint missing
  static String get changePassword => '$base/app/auth/change_password.php'; // TODO: backend endpoint missing
  static String get updateProfile => '$base/app/auth/update_profile.php';

  // ── Profile / Employee ─────────────────────────────────
  static String employeeProfile(int id) =>
      '$base/app/employees/get_profile.php?id=$id';
  static String employeeDocuments(int id) =>
      '$base/app/employees/get_documents.php?employee_id=$id';
  static String get documents => '$base/app/employees/get_documents.php';

  // ── Attendance ─────────────────────────────────────────
  static String get checkIn => '$base/app/attendance/check_in.php';
  static String get checkOut => '$base/app/attendance/check_out.php';
  static String get attendanceSync => '$base/app/attendance/sync_offline.php';
  static String attendanceLogs({int? month, int? year}) {
    final params = <String>[];
    if (month != null) params.add('month=$month');
    if (year != null) params.add('year=$year');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return '$base/app/attendance/get_my_attendance.php$query';
  }

  static String attendanceLogDetail(int id) =>
      '$base/app/attendance/get_my_attendance.php?id=$id';

  // ── Payroll ────────────────────────────────────────────
  static String get payrolls => '$base/app/payroll/list_slips.php';
  static String payrollDetail(int month, int year) =>
      '$base/app/payroll/get_slip.php?month=$month&year=$year';
  static String payrollPdf(int id) =>
      '$base/app/payroll/get_slip.php?id=$id&format=pdf';

  // ── Leaves ─────────────────────────────────────────────
  static String get leaveApply => '$base/app/leaves/apply.php';
  static String get leaveBalance => '$base/app/leaves/get_balance.php';
  static String get myLeaves => '$base/app/leaves/list.php';

  // ── Notifications + Devices ────────────────────────────
  static String get notifications => '$base/app/notifications/list.php'; // TODO: backend missing
  static String notificationRead(int id) =>
      '$base/app/notifications/read.php?id=$id'; // TODO: backend missing
  static String get registerFcm => '$base/app/auth/update_fcm_token.php';
  static String get unregisterFcm => '$base/app/auth/update_fcm_token.php'; // TODO: backend missing
}
