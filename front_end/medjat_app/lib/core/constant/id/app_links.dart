import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppLinks {
  AppLinks._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  static String get activateEmployee =>
      '$base/app/auth/activate_employee.php';

  static String get me => '$base/app/employees/get_profile.php';
  static String get updateProfile => '$base/app/auth/update_profile.php';

  static String get checkIn => '$base/app/attendance/check_in.php';
  static String get checkOut => '$base/app/attendance/check_out.php';
  static String get attendanceSync =>
      '$base/app/attendance/sync_offline.php';
  static String attendanceMonth(String month) =>
      '$base/app/attendance/get_my_attendance.php?month=$month';

  static String payrollSlipMonth(String month) =>
      '$base/app/payroll/get_slip.php?month=$month';
  static String payrollPdf(String month) =>
      '$base/app/payroll/get_slip.php?month=$month&format=pdf';

  static String get leaveApply => '$base/app/leaves/apply.php';
  static String get leaveBalance => '$base/app/leaves/get_balance.php';

  static String get notifications => '$base/app/notifications/list.php';
  static String notificationRead(int id) =>
      '$base/app/notifications/read.php?id=$id';
  static String get registerFcm => '$base/app/auth/update_fcm_token.php';
  static String get notificationPrefs =>
      '$base/app/auth/notification_prefs.php';
}
