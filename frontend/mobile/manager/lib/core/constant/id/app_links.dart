import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppLinks {
  AppLinks._();

  static String get base => dotenv.env['API_HOST'] ?? '';

  // ── Auth ───────────────────────────────────────────────
  static String get login => '$base/v1/auth/admin/login';
  static String get logout => '$base/v1/auth/admin/logout'; 
  // Sign-in doubles as "who am I": the reply carries the user record.
  static String get me => '\$base/v1/auth/admin/login';
  static String get deleteAccount => '$base/v1/auth/account';
  static String get updateProfile => '$base/v1/auth/profile';
  static String get updateFcmToken => '$base/v1/auth/fcm-token';
  static String get sendVerification =>
      '$base/v1/auth/verification';
  static String get sendPasswordReset =>
      '$base/v1/auth/password-reset';

  // ── Tenant onboarding (Create / Join company) ──────────
  static String get tenantCreate => '$base/v1/tenants';
  static String get tenantJoin => '$base/v1/tenants/join';
  static String get tenantAcceptInvitation =>
      '$base/v1/tenants/accept-invitation';

  // ── Dashboard ──────────────────────────────────────────
  static String get dashboard => '$base/v1/dashboard/overview';
  static String get liveAttendance =>
      '$base/v1/dashboard/live-attendance';

  // ── Employees ──────────────────────────────────────────
  static String get employees => '$base/v1/employees';
  static String employeeDetail(int id) {
    // GET → v1/employees/profile, PATCH → v1/employees/{id},
    // POST → v1/employees/{id}/terminate
    // The data layer should be updated to call the right endpoint per method.
    return '$base/v1/employees/profile?id=$id';
  }

  static String get employeeCreate => '$base/v1/employees';
  static String employeeUpdate(int employeeId) => '\$base/v1/employees/$employeeId';
  static String employeeDelete(int employeeId) => '\$base/v1/employees/$employeeId/terminate';
  // Terminated (ended-service) employees + re-hire.
  static String get employeesTerminated =>
      '$base/v1/employees/terminated';
  static String get employeeReactivate =>
      '$base/v1/employees/reactivate';
  static String get employeeSuspend => '$base/v1/employees/suspend';
  static String get employeeEndSuspension =>
      '$base/v1/employees/end-suspension';
  static String employeeSuspensions(int id) =>
      '$base/v1/employees/suspensions?employee_id=$id';
  static String get expiringCompliance =>
      '$base/v1/employees/expiring-compliance';
  static String employeeDocuments(int id) =>
      '$base/v1/employees/documents?employee_id=$id';
  static String employeeDocument(int employeeId, int docId) =>
      '$base/v1/employees/documents?employee_id=$employeeId&doc_id=$docId';
  static String get employeeDocumentUpload =>
      '$base/v1/employees/documents/upload';
  static String documentFileView(int docId) =>
      '$base/v1/documents/view?id=$docId';
  static String employeeUpdateDocument(int documentId) => '\$base/v1/employees/documents/$documentId';
  static String get employeeVerifyDocument =>
      '$base/v1/employees/documents/verify';
  static String get employeeRejectDocument =>
      '$base/v1/employees/documents/reject';
  static String employeeDeleteDocument(int documentId) => '\$base/v1/employees/documents/$documentId';
  static String get employeeRequestDocument =>
      '$base/v1/employees/documents/request';
  static String employeeMissingDocuments(int id) =>
      '$base/v1/employees/documents/missing?employee_id=$id';
  static String employeeActivationCode(int id) =>
      '$base/v1/employees/activation-code?id=$id';
  static String employeeAttendanceHistory(int id,
          {String? month, String? from, String? to}) =>
      from != null && to != null
          ? '$base/v1/employees/attendance-history?employee_id=$id&from=$from&to=$to'
          : '$base/v1/employees/attendance-history?employee_id=$id&month=${month ?? ''}';
  static String employeeFinancialSummary(int id, String month) =>
      '$base/v1/employees/financial-summary?employee_id=$id&month=$month';
  static String employeeYearToDate(int id, int year) =>
      '$base/v1/employees/year-to-date?employee_id=$id&year=$year';

  // ── Required Documents (tenant-level types) ────────────
  static String get documentsRequired =>
      '$base/v1/documents/required';
  static String get documentCreateRequired =>
      '$base/v1/documents/required';
  static String documentUpdateRequired(int id) => '\$base/v1/documents/required/$id';
  static String documentDeleteRequired(int id) => '\$base/v1/documents/required/$id';
  static String get documentToggleRequired =>
      '$base/v1/documents/required/toggle';
  static String get documentMarkExpired =>
      '$base/v1/documents/mark-expired';
  static String documentRequiredSubmissions(int requiredDocumentId) =>
      '$base/v1/documents/required/submissions?required_document_id=$requiredDocumentId';

  // ── Document Reports ───────────────────────────────────
  static String get documentReportsExpiringSoon =>
      '$base/v1/documents/reports/expiring-soon';
  static String get documentReportsExpired =>
      '$base/v1/documents/reports/expired';
  static String get documentReportsMissing =>
      '$base/v1/documents/reports/missing';
  static String get documentReportsStats =>
      '$base/v1/documents/reports/stats';

  // ── Branches ───────────────────────────────────────────
  static String get branches => '$base/v1/branches';
  static String branchDetail(int id) {
    // GET single branch not in backend; v1/branches returns all.
    return '$base/v1/branches?id=$id';
  }

  static String get branchCreate => '$base/v1/branches';
  static String branchUpdate(int branchId) => '\$base/v1/branches/$branchId';
  static String get branchNetworkSightings =>
      '$base/v1/branches/networks/sightings';
  static String get branchApproveNetworks =>
      '$base/v1/branches/networks/approve';
  static String get branchCaptureNetwork =>
      '$base/v1/branches/networks/capture';
  static String get branchUpdateAttendanceMethod =>
      '$base/v1/branches/attendance-method';
  static String get setAttendanceMethodOverride =>
      '$base/v1/attendance/method-override';
  static String get branchGenerateQr =>
      '$base/v1/branches/generate-qr';

  // ── Attendance ─────────────────────────────────────────
  static String get attendance =>
      '$base/v1/attendance/branch';
  /// Browser-punch evidence. Served only through this endpoint — the images sit
  /// under uploads/, which the web server refuses outright.
  static String attendancePunchPhoto(int attendanceId, String which) =>
      '$base/v1/attendance/photo?attendance_id=$attendanceId&which=$which';
  static String get attendanceManual =>
      '$base/v1/attendance/manual';
  static String get attendanceSetDayStatus =>
      '$base/v1/attendance/day-status';
  static String get attendanceUpdateNote =>
      '$base/v1/attendance/note';

  // ── Biometric devices (fingerprint / face terminals) ────
  static String get devices => '$base/v1/devices';
  static String get deviceRegister => '$base/v1/devices';
  static String deviceUpdate(int deviceId) => '\$base/v1/devices/$deviceId';
  static String deviceDelete(int deviceId) => '\$base/v1/devices/$deviceId';
  static String get deviceCommand => '$base/v1/devices/command';
  static String get deviceLinkUser => '$base/v1/devices/link-user';
  static String get deviceImportPunches => '$base/v1/devices/import-punches';
  static String deviceUsers(int deviceId, {String? filter}) =>
      '$base/v1/devices/users?device_id=$deviceId'
      '${filter != null ? '&filter=$filter' : ''}';
  static String devicePunches({int? deviceId, String? state, int limit = 100}) =>
      '$base/v1/devices/punches?limit=$limit'
      '${deviceId != null ? '&device_id=$deviceId' : ''}'
      '${state != null ? '&state=$state' : ''}';

  // ── Branch kiosk (shared tablet) ────────────────────────
  // Distinct from the biometric terminals above: a kiosk is a tablet running
  // our own app, authenticating as a BRANCH rather than reporting punches as a
  // piece of third-party hardware.
  static String get kioskList => '$base/v1/kiosk/stations';
  static String get kioskCreatePairingCode =>
      '$base/v1/kiosk/pairing-code';
  static String get kioskCreateAccessCode =>
      '$base/v1/kiosk/access-code';
  static String get kioskRevoke => '$base/v1/kiosk/revoke';
  static String get kioskSetPin => '$base/v1/kiosk/set-pin';
  static String get kioskRecognitionLogs =>
      '$base/v1/kiosk/recognition-logs';
  static String get kioskCapture => '$base/v1/kiosk/capture';

  // ── Payroll ────────────────────────────────────────────
  static String get payroll => '$base/v1/payroll/slips';
  static String get payrollLive => '$base/v1/payroll/live';
  static String payrollApprove(int id) =>
      '$base/v1/payroll/approve?id=$id';
  static String get payrollApproveBulk =>
      '$base/v1/payroll/approve-bulk';
  static String get payrollMarkPaid =>
      '$base/v1/payroll/mark-paid';
  static String get payrollDisburse =>
      '$base/v1/payroll/disburse';
  static String get payrollDisburseAll =>
      '$base/v1/payroll/disburse-all';
  static String get payrollGenerate => '$base/v1/payroll/generate';
  static String get payrollOverrideLine =>
      '$base/v1/payroll/override-line';
  static String payrollSlipPdf(int employeeId, String month) =>
      '$base/v1/payroll/payslip.pdf?employee_id=$employeeId&month=$month';
  static String payrollEosb(int employeeId) =>
      '$base/v1/payroll/eosb?employee_id=$employeeId';
  static String get payrollSlipApprove =>
      '$base/v1/payroll/approve';
  static String get payrollSlipMarkPaid =>
      '$base/v1/payroll/mark-paid';
  static String get payrollSlipRevert =>
      '$base/v1/payroll/revert';

  // ── Allowances (recurring monthly bonuses: housing, transport, etc.) ──
  static String allowancesList(int employeeId) =>
      '$base/v1/allowances?employee_id=$employeeId';
  static String get allowanceCreate => '$base/v1/allowances';
  static String allowanceUpdate(int id) => '\$base/v1/allowances/$id';
  static String allowanceDelete(int id) => '\$base/v1/allowances/$id';
  static String get payrollAuditLog => '$base/v1/payroll/audit-log';
  static String get payrollBankFile =>
      '$base/v1/payroll/bank-file';
  static String get payrollBankPreview =>
      '$base/v1/payroll/bank-file/preview';

  // ── Leaves ─────────────────────────────────────────────
  static String get leaves => '$base/v1/leaves';
  static String get leaveCreate => '$base/v1/leaves';
  static String leaveApprove(int id) =>
      '$base/v1/leaves/approve?id=$id';
  static String leaveReject(int id) =>
      '$base/v1/leaves/reject?id=$id';
  static String leaveConvertToAbsence(int id) =>
      '$base/v1/leaves/convert-to-absence?id=$id';
  static String get leaveCreateRecurring =>
      '$base/v1/leaves/recurring';
  static String get leaveBalance => '$base/v1/leaves/balance';
  static String get leaveSettings => '$base/v1/settings/leave';
  static String get leaveRollover => '$base/v1/leaves/rollover';
  static String get leaveCarryoverPolicies =>
      '$base/v1/leaves/carryover-policies';
  static String get leaveCarryoverPolicySave =>
      '$base/v1/leaves/carryover-policies';
  static String leaveCarryoverPolicyDelete(int id) => '\$base/v1/leaves/carryover-policies/$id';
  static String get leaveEncashments =>
      '$base/v1/leaves/encashments';

  // ── Breaks / Permissions ───────────────────────────────
  static String get breakRequest   => '$base/v1/breaks/request';
  static String get breakCreateFor => '$base/v1/breaks';
  static String get breakMyList    => '$base/v1/breaks/mine';
  static String get breakCancel    => '$base/v1/breaks/cancel';
  static String get breakList      => '$base/v1/breaks';
  static String get breakApprove   => '$base/v1/breaks/approve';
  static String get breakReject    => '$base/v1/breaks/reject';
  static String get breakPostpone  => '$base/v1/breaks/postpone';

  // ── Deductions / Bonuses ───────────────────────────────
  static String get deductionRules => '$base/v1/deduction-rules';
  static String get deductionSaveConfig =>
      '$base/v1/deduction-rules';
  static String get deductionManualAdd =>
      '$base/v1/deductions/manual';
  static String deductionManualUpdate(int id) => '\$base/v1/deductions/manual/$id';
  static String deductionManualDelete(int id) => '\$base/v1/deductions/manual/$id';
  static String get bonusManualAdd => '$base/v1/bonuses/manual';
  static String bonusManualUpdate(int id) => '\$base/v1/bonuses/manual/$id';
  static String bonusManualDelete(int id) => '\$base/v1/bonuses/manual/$id';

  /// Bulk bonus/deduction applied to every employee in a branch/shift/category.
  static String get payrollBulkAdjust => '$base/v1/payroll/bulk-adjust';

  // ── Bulk adjustments (tracked batches: deduction/bonus to a scope) ──
  static String get bulkAdjustmentList =>
      '$base/v1/bulk-adjustments';
  static String get bulkAdjustmentGet => '$base/v1/bulk-adjustments/get';
  static String get bulkAdjustmentCreate =>
      '$base/v1/bulk-adjustments';
  static String bulkAdjustmentUpdate(int id) => '\$base/v1/bulk-adjustments/$id';
  static String bulkAdjustmentDelete(int id) => '\$base/v1/bulk-adjustments/$id';
  static String get bulkAdjustmentRemoveMember =>
      '$base/v1/bulk-adjustments/remove-member';

  // ── Assets & Custody (items handed to employees) ───────
  static String get assets => '$base/v1/assets';
  static String get assetCreate => '$base/v1/assets';
  static String assetUpdate(int id) => '\$base/v1/assets/$id';
  static String assetDelete(int id) => '\$base/v1/assets/$id';
  static String get assetApproveReturn => '$base/v1/assets/approve-return';
  static String get assetRejectReturn => '$base/v1/assets/reject-return';

  // ── Loans / Advances (auto-deducted installments) ──────
  static String get loans => '$base/v1/loans';
  static String get loanCreate => '$base/v1/loans';
  static String loanDetail(int id) => '$base/v1/loans/show?id=$id';
  static String get loanApprove => '$base/v1/loans/approve';
  static String get loanCancel => '$base/v1/loans/cancel';

  // ── End-of-service settlement (تسوية نهاية الخدمة) ──────
  static String settlement(int employeeId) =>
      '$base/v1/settlements?employee_id=$employeeId';
  static String settlementPreview(int employeeId, String lastWorkingDay) =>
      '$base/v1/settlements/preview?employee_id=$employeeId&last_working_day=$lastWorkingDay';
  static String get settlementSave => '$base/v1/settlements';
  static String get settlementApprove => '$base/v1/settlements/approve';
  static String get settlementMarkPaid => '$base/v1/settlements/mark-paid';

  // ── Warnings ───────────────────────────────────────────
  static String get warningAdd => '$base/v1/warnings';
  static String warningDelete(int id) => '\$base/v1/warnings/$id';

  // ── Performance Reviews ────────────────────────────────
  static String employeeReviews(int employeeId) =>
      '$base/v1/performance/reviews?employee_id=$employeeId';
  static String get performanceReviews =>
      '$base/v1/performance/reviews';
  static String performanceReviewDelete(int id) => '\$base/v1/performance/reviews/$id';

  // ── Roles / Permissions ────────────────────────────────
  static String get roles => '$base/v1/roles/permissions';

  // ── Reports ──────────
  static String get reportAttendance => '$base/v1/reports/attendance';
  static String get reportPayroll => '$base/v1/reports/payroll';
  static String get reportEmployees => '$base/v1/reports/employees';
  static String get reportLeaves => '$base/v1/reports/leaves';
  static String get reportOvertimeLate =>
      '$base/v1/reports/overtime-late';
  static String get reportExportWord => '$base/v1/reports/export.docx';

  // ── Activity log ──────────
  static String get auditLog => '$base/v1/audit';

  // ── Settings (TODO: backend endpoint missing) ──────────
  static String get companySettings => '$base/v1/settings/company';
  static String get statutoryPayrollSettings =>
      '$base/v1/settings/statutory-payroll';
  static String get notifications => '$base/v1/notifications';
  static String notificationRead(int id) =>
      '$base/v1/notifications/read?id=$id';
  static String get notificationPrefs =>
      '$base/v1/auth/notification-prefs';

  // ── Shifts ──────────────────────────────────────────────
  static String get shifts => '$base/v1/shifts';
  static String get shiftCreate => '$base/v1/shifts';
  static String shiftUpdate(int id) => '\$base/v1/shifts/$id';
  static String shiftDelete(int id) => '\$base/v1/shifts/$id';
  static String get shiftAssign => '$base/v1/shifts/assign';
  static String get shiftUnassign => '$base/v1/shifts/unassign';

  // Weekly rotating-shift schedule
  static String get scheduleWeek => '$base/v1/schedule/week';
  static String get scheduleAssign => '$base/v1/schedule/assign';
  static String get scheduleClear => '$base/v1/schedule/clear';
  static String get scheduleCopyWeek => '$base/v1/schedule/copy-week';
  static String get schedulePublish => '$base/v1/schedule/publish';

  // ── Manager Invitations ────────────────────────────────
  static String get managerInvite => '$base/v1/team/invitations';
  static String get managerInvitations => '$base/v1/team/invitations';
  static String get managerCancelInvitation =>
      '\$base/v1/team/invitations/cancel';
  static String managerResendInvitation(int id) =>
      '$base/v1/team/invitations/resend?id=$id';
  static String get adminsList => '$base/v1/team';
  static String adminUpdate(int adminId) => '\$base/v1/team/$adminId';
  static String get adminSetActive => '$base/v1/team/set-active';
  static String get adminRemove => '$base/v1/team/remove';

  // ── Admin Permissions ──────────────────────────────────
  static String adminPermissions(int id) =>
      '$base/v1/team/permissions?admin_id=$id';
  static String get adminPermissionsUpdate =>
      '$base/v1/team/permissions';
  static String get adminPermissionsReset =>
      '$base/v1/team/permissions/reset';

  // ── Biometric ──────────────────────────────────────────
  static String get biometricEnrollFace =>
      '$base/v1/biometric/face';
  static String get biometricEnrollFingerprint =>
      '$base/v1/biometric/fingerprint';
  static String biometricDelete(int employeeId) => '\$base/v1/biometric/$employeeId';
  static String biometricStatus(int employeeId) =>
      '$base/v1/biometric/status?employee_id=$employeeId';

  // ── Categories ─────────────────────────────────────────
  static String get categories => '$base/v1/categories';
  static String get categoryCreate => '$base/v1/categories';
  static String categoryUpdate(int id) => '\$base/v1/categories/$id';
  static String categoryDelete(int id) => '\$base/v1/categories/$id';
  static String get categoryAssign => '$base/v1/categories/assign';
  // Behind manage_company_settings, not manage_employees — it is an attendance
  // decision taken at category grain, not a category edit.
  static String get categoryWebAccess =>
      '$base/v1/categories/web-access';

  // ── Support ────────────────────────────────────────────
  static String get supportTickets => '$base/v1/support/tickets';
  static String get supportCreate => '$base/v1/support/tickets';
  static String supportMessages(int ticketId, {int? afterId}) =>
      afterId != null
          ? '$base/v1/support/messages?ticket_id=$ticketId&after_id=$afterId'
          : '$base/v1/support/messages?ticket_id=$ticketId';
  static String get supportReply => '$base/v1/support/reply';
  static String get supportClose => '$base/v1/support/close';
  // Attachments are not public files: they are fetched through this endpoint
  // with the session's own credentials.
  static String supportAttachment(int messageId) =>
      '$base/v1/support/attachment?message_id=$messageId';
}
