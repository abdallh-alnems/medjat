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
  static String get employeeUpdateDocument =>
      '$base/app/employees/update_document.php';
  static String get employeeVerifyDocument =>
      '$base/app/employees/verify_document.php';
  static String get employeeRejectDocument =>
      '$base/app/employees/reject_document.php';
  static String employeeMissingDocuments(int id) =>
      '$base/app/employees/get_missing_documents.php?employee_id=$id';
  static String employeeActivationCode(int id) =>
      '$base/app/employees/activation_code.php?id=$id';

  // ── Required Documents (tenant-level types) ────────────
  static String get documentsRequired =>
      '$base/app/documents/get_required.php';
  static String get documentCreateRequired =>
      '$base/app/documents/create_required.php';
  static String get documentUpdateRequired =>
      '$base/app/documents/update_required.php';
  static String get documentDeleteRequired =>
      '$base/app/documents/delete_required.php';
  static String get documentToggleRequired =>
      '$base/app/documents/toggle_required.php';
  static String get documentMarkExpired =>
      '$base/app/documents/mark_expired.php';

  // ── Document Reports ───────────────────────────────────
  static String get documentReportsExpiringSoon =>
      '$base/app/documents/reports_expiring_soon.php';
  static String get documentReportsExpired =>
      '$base/app/documents/reports_expired.php';
  static String get documentReportsMissing =>
      '$base/app/documents/reports_missing.php';
  static String get documentReportsStats =>
      '$base/app/documents/reports_stats.php';

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
  static String get branchUpdateAttendanceMethod =>
      '$base/app/branches/update_attendance_method.php';

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

  // ── Performance Reviews ────────────────────────────────
  static String employeeReviews(int employeeId) =>
      '$base/app/performance/list.php?employee_id=$employeeId'; // TODO: backend endpoint missing
  static String get performanceReviews =>
      '$base/app/performance/create.php'; // TODO: backend endpoint missing
  static String performanceReviewDelete(int id) =>
      '$base/app/performance/delete.php?id=$id'; // TODO: backend endpoint missing

  // ── Roles / Permissions ────────────────────────────────
  static String get roles => '$base/app/roles/list_permissions.php';
  static String get permissions => '$base/app/roles/list_permissions.php';
  static String get roleCreate => '$base/app/roles/create_role.php';

  // ── Reports ──────────
  static String get reportAttendance => '$base/app/reports/attendance.php';
  static String get reportPayroll => '$base/app/reports/payroll.php';
  static String get reportEmployees => '$base/app/reports/employees.php';
  static String get reportLeaves => '$base/app/reports/leaves.php';

  // ── Settings (TODO: backend endpoint missing) ──────────
  static String get companySettings => '$base/app/settings/company.php';
  static String get notifications => '$base/app/notifications/list.php';
  static String notificationRead(int id) =>
      '$base/app/notifications/read.php?id=$id';
  static String get registerFcm => '$base/app/auth/update_fcm_token.php';

  // ── Forgot Password (OTP via email) ───────────────────
  static String get forgotPasswordSend => '$base/app/auth/forgot_password.php';
  static String get forgotPasswordVerify => '$base/app/auth/verify_reset_code.php';
  static String get forgotPasswordReset => '$base/app/auth/reset_password.php';

  // ── Shifts ──────────────────────────────────────────────
  static String get shifts => '$base/app/shifts/list.php';
  static String get shiftCreate => '$base/app/shifts/create.php';
  static String shiftUpdate(int id) => '$base/app/shifts/update.php?id=$id';
  static String shiftDelete(int id) => '$base/app/shifts/delete.php?id=$id';
  static String get shiftAssign => '$base/app/shifts/assign.php';

  // ── Manager Invitations ────────────────────────────────
  static String get managerInvite => '$base/app/managers/invite.php';
  static String get managerInvitations => '$base/app/managers/list_invitations.php';
  static String managerCancelInvitation(int id) =>
      '$base/app/managers/cancel_invitation.php?id=$id';
  static String get adminsList => '$base/app/managers/list_admins.php';

  // ── Admin Permissions ──────────────────────────────────
  static String adminPermissions(int id) =>
      '$base/app/managers/get_admin_permissions.php?admin_id=$id';
  static String get adminPermissionsUpdate =>
      '$base/app/managers/update_admin_permissions.php';
  static String get adminPermissionsReset =>
      '$base/app/managers/reset_admin_permissions.php';

  // ── Biometric ──────────────────────────────────────────
  static String get biometricEnrollFace =>
      '$base/app/biometric/enroll_face.php';
  static String get biometricEnrollFingerprint =>
      '$base/app/biometric/enroll_fingerprint.php';
  static String get biometricDelete => '$base/app/biometric/delete.php';
  static String biometricStatus(int employeeId) =>
      '$base/app/biometric/status.php?employee_id=$employeeId';

  // ── Stations ───────────────────────────────────────────
  static String get stationCreate => '$base/app/stations/create.php';
  static String get stationList => '$base/app/stations/list.php';
  static String stationDetail(int id) =>
      '$base/app/stations/get.php?id=$id';
  static String get stationUpdate => '$base/app/stations/update.php';
  static String get stationDelete => '$base/app/stations/delete.php';
  static String get stationRegenerateQR =>
      '$base/app/stations/regenerate_qr.php';
  static String get stationUnlock => '$base/app/stations/unlock.php';
  static String get stationLogs => '$base/app/stations/logs.php';
  static String get stationBranchSettings =>
      '$base/app/stations/update_branch_settings.php';
}
