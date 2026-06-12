import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppLinks {
  AppLinks._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  static String get employeeLogin =>
      '$base/app/auth/employee_login.php';
  static String get employeeActivateToken =>
      '$base/app/auth/employee_activate_token.php';
  static String get employeeLogout =>
      '$base/app/auth/employee_logout.php';

  static String get myProfile => '$base/app/employees/my_profile.php';
  static String get submitDocument =>
      '$base/app/employees/submit_document.php';
  static String get myDocumentView =>
      '$base/app/employees/my_document_view.php';

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
  static String get leaveBalance => '$base/app/leaves/my_balance.php';
  static String get myLeaves => '$base/app/leaves/my_leaves.php';
  static String get leaveCancel => '$base/app/leaves/cancel.php';
  static String get leaveUpdate => '$base/app/leaves/update.php';

  static String get breakRequest => '$base/app/breaks/request.php';
  static String get myBreaks => '$base/app/breaks/my_list.php';
  static String get breakCancel => '$base/app/breaks/cancel.php';
  static String get breakRespondPostpone =>
      '$base/app/breaks/respond_postpone.php';

  static String get advanceRequest => '$base/app/loans/request.php';
  static String get myAdvances => '$base/app/loans/my_list.php';
  static String get advanceCancel => '$base/app/loans/cancel_request.php';

  static String get myAssets => '$base/app/assets/my_list.php';
  static String get assetRequestReturn =>
      '$base/app/assets/request_return.php';

  static String get notifications => '$base/app/notifications/list.php';
  static String notificationRead(int id) =>
      '$base/app/notifications/read.php?id=$id';
  static String get registerFcm => '$base/app/auth/update_fcm_token.php';
  static String get notificationPrefs =>
      '$base/app/auth/notification_prefs.php';
  static String get myStationQr => '$base/app/employees/my_station_qr.php';
  static String get attendanceSecurityLog =>
      '$base/app/attendance/security_log.php';
}
