import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppLinks {
  AppLinks._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  static String get login => '$base/auth/login';
  static String get logout => '$base/auth/logout';
  static String get refresh => '$base/auth/refresh';
  static String get forgotPassword => '$base/auth/forgot-password';
  static String get changePassword => '$base/auth/change-password';
  static String get me => '$base/me';
  static String get today => '$base/me/today';
  static String get checkIn => '$base/attendance/check-in';
  static String get checkOut => '$base/attendance/check-out';
  static String get attendanceSync => '$base/attendance/sync';
  static String attendanceLogs({int? month, int? year}) {
    final params = <String>[];
    if (month != null) params.add('month=$month');
    if (year != null) params.add('year=$year');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return '$base/me/attendance-logs$query';
  }

  static String attendanceLogDetail(int id) => '$base/me/attendance-logs/$id';
  static String get payrolls => '$base/me/payrolls';
  static String payrollDetail(int month, int year) =>
      '$base/me/payrolls/$month/$year';
  static String payrollPdf(int id) => '$base/me/payrolls/$id/pdf';
  static String get documents => '$base/me/documents';
  static String get notifications => '$base/me/notifications';
  static String notificationRead(int id) =>
      '$base/me/notifications/$id/read';
  static String get registerFcm => '$base/devices/register-fcm';
  static String get unregisterFcm => '$base/devices/unregister-fcm';
}
