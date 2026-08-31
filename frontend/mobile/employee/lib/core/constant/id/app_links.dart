import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppLinks {
  AppLinks._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  static String get employeeLogin =>
      '$base/v1/auth/employee/login';
  static String get employeeActivateToken =>
      '$base/v1/auth/employee/activate';
  static String get employeeLogout =>
      '$base/v1/auth/employee/logout';

  static String get myProfile => '$base/v1/employees/me';
  static String get submitDocument =>
      '$base/v1/employees/documents/submit';
  static String get myDocumentView =>
      '$base/v1/employees/documents/mine';

  static String get checkIn => '$base/v1/attendance/check-in';
  static String get checkOut => '$base/v1/attendance/check-out';
  static String get attendanceSync =>
      '$base/v1/attendance/sync-offline';

  // Crew attendance: a supervisor records for the people on site with them.
  static String get crewList => '$base/v1/attendance/crew';
  static String get crewCheckIn => '$base/v1/attendance/crew/punch';
  static String attendanceMonth(String month) =>
      '$base/v1/attendance/mine?month=$month';

  static String payrollSlipMonth(String month) =>
      '$base/v1/payroll/me?month=$month';
  static String payrollPdf(String month) =>
      '$base/v1/payroll/me?month=$month&format=pdf';

  static String get leaveApply => '$base/v1/leaves/apply';
  static String get leaveBalance => '$base/v1/leaves/my-balance';
  static String get myLeaves => '$base/v1/leaves/mine';
  static String get leaveCancel => '$base/v1/leaves/cancel';
  static String leaveUpdate(int leaveId) => '\$base/v1/leaves/\$leaveId';

  static String get breakRequest => '$base/v1/breaks/request';
  static String get myBreaks => '$base/v1/breaks/mine';
  static String get breakCancel => '$base/v1/breaks/cancel';
  static String get breakRespondPostpone =>
      '$base/v1/breaks/respond-postpone';

  static String get advanceRequest => '$base/v1/loans/request';
  static String get myAdvances => '$base/v1/loans/mine';
  static String get advanceCancel => '$base/v1/loans/cancel-request';

  static String get myAssets => '$base/v1/assets/mine';
  static String get assetRequestReturn =>
      '$base/v1/assets/request-return';

  static String get notifications => '$base/v1/notifications';
  static String notificationRead(int id) =>
      '$base/v1/notifications/read?id=$id';
  static String get registerFcm => '$base/v1/auth/fcm-token';
  static String get notificationPrefs =>
      '$base/v1/auth/notification-prefs';
  static String get attendanceSecurityLog =>
      '$base/v1/attendance/security-log';

  // Face check-in (face_selfie)
  static String get faceChallenge => '$base/v1/attendance/face-challenge';
  static String get faceEnrollSelf => '$base/v1/biometric/self/face';
  static String get faceMyStatus => '$base/v1/biometric/self/status';
}
