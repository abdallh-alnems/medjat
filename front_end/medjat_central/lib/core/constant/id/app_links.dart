import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppLinks {
  AppLinks._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  // ── Auth ───────────────────────────────────────────────
  static String get login => '$base/app/auth/login.php';
  static String get logout => '$base/app/auth/logout.php'; // TODO: backend endpoint missing
  static String get me => '$base/app/auth/login.php'; // login.php returns user info
  static String get updateProfile => '$base/app/auth/update_profile.php';
  static String get updateFcmToken => '$base/app/auth/update_fcm_token.php';

  // ── Tenant onboarding (Create / Join company) ──────────
  static String get tenantCreate => '$base/app/tenant/create.php';
  static String get tenantJoin => '$base/app/tenant/join.php';

  // ── Dashboard ──────────────────────────────────────────
  static String get dashboard => '$base/app/dashboard/overview.php';
  static String get branchComparison => '$base/app/dashboard/branch_comparison.php';

  // ── Employees ──────────────────────────────────────────
  static String get employees => '$base/app/employees/list.php';
  static String employeeDetail(int id) {
    // GET → get_profile.php, PUT → update.php, DELETE → delete.php
    // The data layer should be updated to call the right endpoint per method.
    return '$base/app/employees/get_profile.php?id=$id';
  }

  static String get employeeCreate => '$base/app/employees/create.php';
  static String get employeeUpdate => '$base/app/employees/update.php';
  static String get employeeDelete => '$base/app/employees/delete.php';
  static String employeeDocuments(int id) =>
      '$base/app/employees/get_documents.php?employee_id=$id';
  static String employeeDocument(int employeeId, int docId) =>
      '$base/app/employees/get_documents.php?employee_id=$employeeId&doc_id=$docId';
  static String get employeeDocumentUpload =>
      '$base/app/employees/upload_document.php';
  static String employeeActivationCode(int id) =>
      '$base/app/employees/activation_code.php?id=$id'; // TODO: backend endpoint missing

  // ── Branches ───────────────────────────────────────────
  static String get branches => '$base/app/branches/list.php';
  static String branchDetail(int id) {
    // GET single branch not in backend; list.php returns all.
    return '$base/app/branches/list.php?id=$id';
  }

  static String get branchCreate => '$base/app/branches/create.php';
  static String get branchUpdate => '$base/app/branches/update.php';
  static String get branchDelete => '$base/app/branches/delete.php';
  static String branchQr(int id) => '$base/app/branches/get_qr.php?id=$id';
  static String get branchUpdateGps => '$base/app/branches/update_gps.php';

  // ── Attendance ─────────────────────────────────────────
  static String get attendance =>
      '$base/app/attendance/get_branch_attendance.php';
  static String get attendanceManual =>
      '$base/app/attendance/manual_check_in.php';
  static String get attendanceCheckIn => '$base/app/attendance/check_in.php';
  static String get attendanceCheckOut => '$base/app/attendance/check_out.php';
  static String get attendanceSync => '$base/app/attendance/sync_offline.php';

  // ── Payroll ────────────────────────────────────────────
  static String get payroll => '$base/app/payroll/list_slips.php';
  static String get payrollGenerate => '$base/app/payroll/generate.php';
  static String get payrollCalculate => '$base/app/payroll/calculate.php';
  static String payrollApprove(int id) =>
      '$base/app/payroll/approve.php?id=$id';
  static String payrollMonth(int month, int year) =>
      '$base/app/payroll/get_slip.php?month=$month&year=$year';

  // ── Leaves ─────────────────────────────────────────────
  static String get leaves => '$base/app/leaves/list.php';
  static String get leaveApply => '$base/app/leaves/apply.php';
  static String leaveApprove(int id) =>
      '$base/app/leaves/approve.php?id=$id';
  static String leaveReject(int id) =>
      '$base/app/leaves/reject.php?id=$id';
  static String get leaveConvertAbsence =>
      '$base/app/leaves/convert_absence.php';
  static String get leaveCreateRecurring =>
      '$base/app/leaves/create_recurring.php';
  static String get leaveBalance => '$base/app/leaves/get_balance.php';

  // ── Deductions / Bonuses ───────────────────────────────
  static String get deductionRules => '$base/app/deductions/get_rules.php';
  static String get deductionRulesUpdate =>
      '$base/app/deductions/update_rules.php';
  static String get deductionManualAdd =>
      '$base/app/deductions/add_manual.php';
  static String get bonusRules => '$base/app/bonuses/get_rules.php';
  static String get bonusRulesUpdate => '$base/app/bonuses/update_rules.php';
  static String get bonusManualAdd => '$base/app/bonuses/add_manual.php';

  // ── Warnings ───────────────────────────────────────────
  static String get warnings => '$base/app/warnings/list.php';
  static String get warningAdd => '$base/app/warnings/add.php';

  // ── Roles / Permissions ────────────────────────────────
  static String get roles => '$base/app/roles/list_permissions.php';
  static String get permissions => '$base/app/roles/list_permissions.php';
  static String get roleCreate => '$base/app/roles/create_role.php';

  // ── Reports (TODO: backend endpoints missing) ──────────
  static String get reportAttendance => '$base/app/reports/attendance.php';
  static String get reportPayroll => '$base/app/reports/payroll.php';

  // ── Settings (TODO: backend endpoint missing) ──────────
  static String get companySettings => '$base/app/settings/company.php';
  static String get notifications => '$base/app/notifications/list.php';
  static String notificationRead(int id) =>
      '$base/app/notifications/read.php?id=$id';
  static String get registerFcm => '$base/app/auth/update_fcm_token.php';
}
