abstract class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String verifyEmail = '/verify-email';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String employeeDetail = '/employee/:id';
  static const String employeeAdd = '/employee/add';
  static const String attendanceManual = '/attendance/manual';
  static const String payrollDetail = '/payroll/:month/:year';
  static const String leaveManage = '/leave/manage';
  static const String branchManage = '/branch/manage';
  static const String branchQrPoster = '/branch/qr-poster';
  static const String reports = '/reports';
  static const String reportAttendance = '/reports/attendance';
  static const String reportPayroll = '/reports/payroll';
  static const String reportEmployees = '/reports/employees';
  static const String reportLeaves = '/reports/leaves';
  static const String reportOvertimeLate = '/reports/overtime-late';
  static const String loans = '/loans';
  static const String bulkAdjustments = '/bulk-adjustments';
  static const String bulkAdjustmentCreate = '/bulk-adjustments/new';
  static const String bulkAdjustmentDetail = '/bulk-adjustments/detail';
  static const String auditLog = '/activity-log';
  static const String deductionRules = '/settings/deduction-rules';
  static const String attendanceMethod = '/settings/attendance-method';
  static const String branchNetworks = '/settings/branch-networks';
  static const String devices = '/settings/devices';
  static const String deviceUsers = '/settings/devices/users';
  static const String importPunches = '/settings/devices/import';
  static const String companySettings = '/settings/company';
  static const String leaveSettings = '/settings/leave';
  static const String leaveCarryoverPolicies =
      '/settings/leave/carryover-policies';
  static const String leaveEncashments = '/settings/leave/encashments';
  static const String forgotPassword = '/forgot-password';
  static const String shifts = '/shifts';
  static const String assignShift = '/shifts/assign';
  static const String shiftMembers = '/shifts/members';
  static const String weeklySchedule = '/shifts/schedule';
  static const String settingsCompany = '/settings/company-hub';
  static const String settingsAccount = '/settings/account';
  static const String settingsApp = '/settings/app';
  static const String team = '/team';
  static const String inviteAdmin = '/team/invite';
  static const String invitationCode = '/team/invite/code';
  static const String requiredDocuments = '/settings/required-documents';
  static const String requiredDocumentSubmissions =
      '/settings/required-documents/submissions';
  static const String employeeDocuments = '/employee/documents';
  static const String documentsReport = '/reports/documents';
  static const String categories = '/settings/categories';
  static const String categoryEmployees = '/settings/categories/employees';
  static const String statutoryPayrollSettings = '/settings/statutory-payroll';
  static const String notifications = '/notifications';
  static const String notificationPrefs = '/notifications/prefs';
  static const String assets = '/assets';
  static const String statusEmployees = '/status-employees';
  static const String expiringCompliance = '/compliance/expiring';
  static const String support = '/support';
  static const String supportChat = '/support/chat';
  static const String supportNew = '/support/new';
  static const String breakManage = '/break/manage';
  // Single top-level segment (NOT '/employee/settlement') so it is not captured
  // by the parametric route '/employee/:id' (employeeDetail), which is
  // registered first and would otherwise match it (id = "settlement"), leaving
  // the "End of Service" button doing nothing.
  static const String employeeSettlement = '/employee-settlement';
  // Same reasoning: a single top-level segment, safe from '/employee/:id'.
  static const String terminatedEmployees = '/terminated-employees';
}
