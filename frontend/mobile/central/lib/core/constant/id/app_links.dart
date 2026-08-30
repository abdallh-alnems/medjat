import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppLinks {
  AppLinks._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  // ── Auth ───────────────────────────────────────────────
  static String get login => '$base/app/auth/login.php';
  static String get logout => '$base/app/auth/logout.php'; 
  static String get me => '$base/app/auth/login.php'; // login.php returns user info
  static String get deleteAccount => '$base/app/auth/delete_account.php';
  static String get updateProfile => '$base/app/auth/update_profile.php';
  static String get updateFcmToken => '$base/app/auth/update_fcm_token.php';
  static String get sendVerification =>
      '$base/app/auth/send_verification.php';
  static String get sendPasswordReset =>
      '$base/app/auth/send_password_reset.php';

  // ── Tenant onboarding (Create / Join company) ──────────
  static String get tenantCreate => '$base/app/tenant/create.php';
  static String get tenantJoin => '$base/app/tenant/join.php';
  static String get tenantAcceptInvitation =>
      '$base/app/tenant/accept_invitation.php';

  // ── Dashboard ──────────────────────────────────────────
  static String get dashboard => '$base/app/dashboard/overview.php';
  static String get liveAttendance =>
      '$base/app/dashboard/live_attendance.php';

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
  // Terminated (ended-service) employees + re-hire.
  static String get employeesTerminated =>
      '$base/app/employees/list_terminated.php';
  static String get employeeReactivate =>
      '$base/app/employees/reactivate.php';
  static String get employeeSuspend => '$base/app/employees/suspend.php';
  static String get employeeEndSuspension =>
      '$base/app/employees/end_suspension.php';
  static String employeeSuspensions(int id) =>
      '$base/app/employees/get_suspensions.php?employee_id=$id';
  static String get expiringCompliance =>
      '$base/app/employees/expiring_compliance.php';
  static String employeeDocuments(int id) =>
      '$base/app/employees/get_documents.php?employee_id=$id';
  static String employeeDocument(int employeeId, int docId) =>
      '$base/app/employees/get_documents.php?employee_id=$employeeId&doc_id=$docId';
  static String get employeeDocumentUpload =>
      '$base/app/employees/upload_document.php';
  static String documentFileView(int docId) =>
      '$base/app/documents/view.php?id=$docId';
  static String get employeeUpdateDocument =>
      '$base/app/employees/update_document.php';
  static String get employeeVerifyDocument =>
      '$base/app/employees/verify_document.php';
  static String get employeeRejectDocument =>
      '$base/app/employees/reject_document.php';
  static String get employeeDeleteDocument =>
      '$base/app/employees/delete_document.php';
  static String get employeeRequestDocument =>
      '$base/app/employees/request_document.php';
  static String employeeMissingDocuments(int id) =>
      '$base/app/employees/get_missing_documents.php?employee_id=$id';
  static String employeeActivationCode(int id) =>
      '$base/app/employees/activation_code.php?id=$id';
  static String employeeAttendanceHistory(int id,
          {String? month, String? from, String? to}) =>
      from != null && to != null
          ? '$base/app/employees/get_attendance_history.php?employee_id=$id&from=$from&to=$to'
          : '$base/app/employees/get_attendance_history.php?employee_id=$id&month=${month ?? ''}';
  static String employeeFinancialSummary(int id, String month) =>
      '$base/app/employees/get_financial_summary.php?employee_id=$id&month=$month';
  static String employeeYearToDate(int id, int year) =>
      '$base/app/employees/get_year_to_date.php?employee_id=$id&year=$year';

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
  static String documentRequiredSubmissions(int requiredDocumentId) =>
      '$base/app/documents/get_required_submissions.php?required_document_id=$requiredDocumentId';

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
  static String get branchNetworkSightings =>
      '$base/app/branches/network_sightings.php';
  static String get branchApproveNetworks =>
      '$base/app/branches/approve_networks.php';
  static String get branchCaptureNetwork =>
      '$base/app/branches/capture_network.php';
  static String get branchUpdateAttendanceMethod =>
      '$base/app/branches/update_attendance_method.php';
  static String get setAttendanceMethodOverride =>
      '$base/app/attendance/set_method_override.php';
  static String get branchGenerateQr =>
      '$base/app/branches/generate_qr.php';

  // ── Attendance ─────────────────────────────────────────
  static String get attendance =>
      '$base/app/attendance/get_branch_attendance.php';
  /// Browser-punch evidence. Served only through this endpoint — the images sit
  /// under uploads/, which the web server refuses outright.
  static String attendancePunchPhoto(int attendanceId, String which) =>
      '$base/app/attendance/punch_photo.php?attendance_id=$attendanceId&which=$which';
  static String get attendanceManual =>
      '$base/app/attendance/manual_check_in.php';
  static String get attendanceSetDayStatus =>
      '$base/app/attendance/set_day_status.php';
  static String get attendanceUpdateNote =>
      '$base/app/attendance/update_note.php';

  // ── Biometric devices (fingerprint / face terminals) ────
  static String get devices => '$base/app/devices/list.php';
  static String get deviceRegister => '$base/app/devices/register.php';
  static String get deviceUpdate => '$base/app/devices/update.php';
  static String get deviceDelete => '$base/app/devices/delete.php';
  static String get deviceCommand => '$base/app/devices/command.php';
  static String get deviceLinkUser => '$base/app/devices/link_user.php';
  static String get deviceImportPunches => '$base/app/devices/import_punches.php';
  static String deviceUsers(int deviceId, {String? filter}) =>
      '$base/app/devices/users.php?device_id=$deviceId'
      '${filter != null ? '&filter=$filter' : ''}';
  static String devicePunches({int? deviceId, String? state, int limit = 100}) =>
      '$base/app/devices/punches.php?limit=$limit'
      '${deviceId != null ? '&device_id=$deviceId' : ''}'
      '${state != null ? '&state=$state' : ''}';

  // ── Branch kiosk (shared tablet) ────────────────────────
  // Distinct from the biometric terminals above: a kiosk is a tablet running
  // our own app, authenticating as a BRANCH rather than reporting punches as a
  // piece of third-party hardware.
  static String get kioskList => '$base/app/kiosk/list.php';
  static String get kioskCreatePairingCode =>
      '$base/app/kiosk/create_pairing_code.php';
  static String get kioskCreateAccessCode =>
      '$base/app/kiosk/create_access_code.php';
  static String get kioskRevoke => '$base/app/kiosk/revoke.php';
  static String get kioskSetPin => '$base/app/kiosk/set_pin.php';
  static String get kioskRecognitionLogs =>
      '$base/app/kiosk/recognition_logs.php';
  static String get kioskCapture => '$base/app/kiosk/capture.php';

  // ── Payroll ────────────────────────────────────────────
  static String get payroll => '$base/app/payroll/list_slips.php';
  static String get payrollLive => '$base/app/payroll/live.php';
  static String payrollApprove(int id) =>
      '$base/app/payroll/approve.php?id=$id';
  static String get payrollApproveBulk =>
      '$base/app/payroll/approve_bulk.php';
  static String get payrollMarkPaid =>
      '$base/app/payroll/mark_paid.php';
  static String get payrollDisburse =>
      '$base/app/payroll/disburse.php';
  static String get payrollDisburseAll =>
      '$base/app/payroll/disburse_all.php';
  static String get payrollGenerate => '$base/app/payroll/generate.php';
  static String get payrollOverrideLine =>
      '$base/app/payroll/override_line.php';
  static String payrollSlipPdf(int employeeId, String month) =>
      '$base/app/payroll/get_slip_pdf.php?employee_id=$employeeId&month=$month';
  static String payrollEosb(int employeeId) =>
      '$base/app/payroll/eosb_calculate.php?employee_id=$employeeId';
  static String get payrollSlipApprove =>
      '$base/app/payroll/approve.php';
  static String get payrollSlipMarkPaid =>
      '$base/app/payroll/mark_paid.php';
  static String get payrollSlipRevert =>
      '$base/app/payroll/revert.php';

  // ── Allowances (recurring monthly bonuses: housing, transport, etc.) ──
  static String allowancesList(int employeeId) =>
      '$base/app/allowances/list.php?employee_id=$employeeId';
  static String get allowanceCreate => '$base/app/allowances/create.php';
  static String get allowanceUpdate => '$base/app/allowances/update.php';
  static String get allowanceDelete => '$base/app/allowances/delete.php';
  static String get payrollAuditLog => '$base/app/payroll/audit_log.php';
  static String get payrollBankFile =>
      '$base/app/payroll/export_bank_file.php';
  static String get payrollBankPreview =>
      '$base/app/payroll/bank_file_preview.php';

  // ── Leaves ─────────────────────────────────────────────
  static String get leaves => '$base/app/leaves/list.php';
  static String get leaveCreate => '$base/app/leaves/create.php';
  static String leaveApprove(int id) =>
      '$base/app/leaves/approve.php?id=$id';
  static String leaveReject(int id) =>
      '$base/app/leaves/reject.php?id=$id';
  static String leaveConvertToAbsence(int id) =>
      '$base/app/leaves/convert_to_absence.php?id=$id';
  static String get leaveCreateRecurring =>
      '$base/app/leaves/create_recurring.php';
  static String get leaveBalance => '$base/app/leaves/get_balance.php';
  static String get leaveSettings => '$base/app/settings/leave_settings.php';
  static String get leaveRollover => '$base/app/leaves/rollover.php';
  static String get leaveCarryoverPolicies =>
      '$base/app/leaves/carryover_policies_list.php';
  static String get leaveCarryoverPolicySave =>
      '$base/app/leaves/carryover_policy_save.php';
  static String get leaveCarryoverPolicyDelete =>
      '$base/app/leaves/carryover_policy_delete.php';
  static String get leaveEncashments =>
      '$base/app/leaves/encashments_list.php';

  // ── Breaks / Permissions ───────────────────────────────
  static String get breakRequest   => '$base/app/breaks/request.php';
  static String get breakCreateFor => '$base/app/breaks/create_for.php';
  static String get breakMyList    => '$base/app/breaks/my_list.php';
  static String get breakCancel    => '$base/app/breaks/cancel.php';
  static String get breakList      => '$base/app/breaks/list.php';
  static String get breakApprove   => '$base/app/breaks/approve.php';
  static String get breakReject    => '$base/app/breaks/reject.php';
  static String get breakPostpone  => '$base/app/breaks/postpone.php';

  // ── Deductions / Bonuses ───────────────────────────────
  static String get deductionRules => '$base/app/deductions/get_rules.php';
  static String get deductionSaveConfig =>
      '$base/app/deductions/save_config.php';
  static String get deductionManualAdd =>
      '$base/app/deductions/add_manual.php';
  static String get deductionManualUpdate =>
      '$base/app/deductions/update_manual.php';
  static String get deductionManualDelete =>
      '$base/app/deductions/delete_manual.php';
  static String get bonusManualAdd => '$base/app/bonuses/add_manual.php';
  static String get bonusManualUpdate => '$base/app/bonuses/update_manual.php';
  static String get bonusManualDelete => '$base/app/bonuses/delete_manual.php';

  /// Bulk bonus/deduction applied to every employee in a branch/shift/category.
  static String get payrollBulkAdjust => '$base/app/payroll/bulk_adjust.php';

  // ── Bulk adjustments (tracked batches: deduction/bonus to a scope) ──
  static String get bulkAdjustmentList =>
      '$base/app/bulk_adjustments/list.php';
  static String get bulkAdjustmentGet => '$base/app/bulk_adjustments/get.php';
  static String get bulkAdjustmentCreate =>
      '$base/app/bulk_adjustments/create.php';
  static String get bulkAdjustmentUpdate =>
      '$base/app/bulk_adjustments/update.php';
  static String get bulkAdjustmentDelete =>
      '$base/app/bulk_adjustments/delete.php';
  static String get bulkAdjustmentRemoveMember =>
      '$base/app/bulk_adjustments/remove_member.php';

  // ── Assets & Custody (items handed to employees) ───────
  static String get assets => '$base/app/assets/list.php';
  static String get assetCreate => '$base/app/assets/create.php';
  static String get assetUpdate => '$base/app/assets/update.php';
  static String get assetDelete => '$base/app/assets/delete.php';
  static String get assetApproveReturn => '$base/app/assets/approve_return.php';
  static String get assetRejectReturn => '$base/app/assets/reject_return.php';

  // ── Loans / Advances (auto-deducted installments) ──────
  static String get loans => '$base/app/loans/list.php';
  static String get loanCreate => '$base/app/loans/create.php';
  static String loanDetail(int id) => '$base/app/loans/get.php?id=$id';
  static String get loanApprove => '$base/app/loans/approve.php';
  static String get loanCancel => '$base/app/loans/cancel.php';

  // ── End-of-service settlement (تسوية نهاية الخدمة) ──────
  static String settlement(int employeeId) =>
      '$base/app/settlements/get.php?employee_id=$employeeId';
  static String settlementPreview(int employeeId, String lastWorkingDay) =>
      '$base/app/settlements/preview.php?employee_id=$employeeId&last_working_day=$lastWorkingDay';
  static String get settlementSave => '$base/app/settlements/save.php';
  static String get settlementApprove => '$base/app/settlements/approve.php';
  static String get settlementMarkPaid => '$base/app/settlements/mark_paid.php';

  // ── Warnings ───────────────────────────────────────────
  static String get warningAdd => '$base/app/warnings/add.php';
  static String get warningDelete => '$base/app/warnings/delete.php';

  // ── Performance Reviews ────────────────────────────────
  static String employeeReviews(int employeeId) =>
      '$base/app/performance/review_list.php?employee_id=$employeeId';
  static String get performanceReviews =>
      '$base/app/performance/review_create.php';
  static String get performanceReviewDelete =>
      '$base/app/performance/review_delete.php';

  // ── Roles / Permissions ────────────────────────────────
  static String get roles => '$base/app/roles/list_permissions.php';

  // ── Reports ──────────
  static String get reportAttendance => '$base/app/reports/attendance.php';
  static String get reportPayroll => '$base/app/reports/payroll.php';
  static String get reportEmployees => '$base/app/reports/employees.php';
  static String get reportLeaves => '$base/app/reports/leaves.php';
  static String get reportOvertimeLate =>
      '$base/app/reports/overtime_late.php';
  static String get reportExportWord => '$base/app/reports/export_word.php';

  // ── Activity log ──────────
  static String get auditLog => '$base/app/audit/list.php';

  // ── Settings (TODO: backend endpoint missing) ──────────
  static String get companySettings => '$base/app/settings/company.php';
  static String get statutoryPayrollSettings =>
      '$base/app/settings/statutory_payroll.php';
  static String get notifications => '$base/app/notifications/list.php';
  static String notificationRead(int id) =>
      '$base/app/notifications/read.php?id=$id';
  static String get notificationPrefs =>
      '$base/app/auth/notification_prefs.php';

  // ── Shifts ──────────────────────────────────────────────
  static String get shifts => '$base/app/shifts/list.php';
  static String get shiftCreate => '$base/app/shifts/create.php';
  static String shiftUpdate(int id) => '$base/app/shifts/update.php?id=$id';
  static String shiftDelete(int id) => '$base/app/shifts/delete.php?id=$id';
  static String get shiftAssign => '$base/app/shifts/assign.php';
  static String get shiftUnassign => '$base/app/shifts/unassign.php';

  // Weekly rotating-shift schedule
  static String get scheduleWeek => '$base/app/schedule/week.php';
  static String get scheduleAssign => '$base/app/schedule/assign.php';
  static String get scheduleClear => '$base/app/schedule/clear.php';
  static String get scheduleCopyWeek => '$base/app/schedule/copy_week.php';
  static String get schedulePublish => '$base/app/schedule/publish.php';

  // ── Manager Invitations ────────────────────────────────
  static String get managerInvite => '$base/app/managers/invite.php';
  static String get managerInvitations => '$base/app/managers/list_invitations.php';
  static String managerCancelInvitation(int id) =>
      '$base/app/managers/cancel_invitation.php?id=$id';
  static String managerResendInvitation(int id) =>
      '$base/app/managers/resend_invitation.php?id=$id';
  static String get adminsList => '$base/app/managers/list_admins.php';
  static String get adminUpdate => '$base/app/managers/update_admin.php';
  static String get adminSetActive => '$base/app/managers/set_admin_active.php';
  static String get adminRemove => '$base/app/managers/remove_admin.php';

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

  // ── Categories ─────────────────────────────────────────
  static String get categories => '$base/app/categories/list.php';
  static String get categoryCreate => '$base/app/categories/create.php';
  static String get categoryUpdate => '$base/app/categories/update.php';
  static String get categoryDelete => '$base/app/categories/delete.php';
  static String get categoryAssign => '$base/app/categories/assign.php';
  // Behind manage_company_settings, not manage_employees — it is an attendance
  // decision taken at category grain, not a category edit.
  static String get categoryWebAccess =>
      '$base/app/categories/update_web_access.php';

  // ── Support ────────────────────────────────────────────
  static String get supportTickets => '$base/app/support/list.php';
  static String get supportCreate => '$base/app/support/create.php';
  static String supportMessages(int ticketId, {int? afterId}) =>
      afterId != null
          ? '$base/app/support/messages.php?ticket_id=$ticketId&after_id=$afterId'
          : '$base/app/support/messages.php?ticket_id=$ticketId';
  static String get supportReply => '$base/app/support/reply.php';
  static String get supportClose => '$base/app/support/close.php';
  // Attachments are not public files: they are fetched through this endpoint
  // with the session's own credentials.
  static String supportAttachment(int messageId) =>
      '$base/app/support/attachment.php?message_id=$messageId';
}
