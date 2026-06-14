import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../class/crud.dart';
import 'app_routes.dart';
import '../theme/theme.dart';
import '../../services/connectivity_service.dart';
import '../../services/dark_light_service.dart';
import '../../services/update_service.dart';
import '../../widget/maintenance_gate.dart';
import '../../widget/update_gate.dart';
import '../../../data/data_source/remote/auth_data/auth_data.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/data_source/remote/break_data/break_data.dart';
import '../../../data/data_source/remote/performance_data/performance_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/document_data/document_data.dart';
import '../../../data/data_source/remote/deduction_rule_data/deduction_rule_data.dart';
import '../../../logic/controller/settings/deduction_rules_controller.dart';
import '../../../data/data_source/remote/company_settings_data/company_settings_data.dart';
import '../../../data/data_source/remote/shift_data/shift_data.dart';
import '../../../data/data_source/remote/report_data/report_data.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../../../logic/bindings/home_binding.dart';
import '../../../view/screen/auth/login_screen.dart';
import '../../../view/screen/auth/signup_screen.dart';
import '../../../view/screen/auth/verify_email_screen.dart';
import '../../../view/screen/auth/forgot_password_screen.dart';
import '../../../view/screen/splash/splash_screen.dart';
import '../../../view/screen/onboarding/onboarding_screen.dart';
import '../../../view/screen/dashboard/dashboard_screen.dart';
import '../../../view/screen/employee/employees_screen.dart';
import '../../../view/screen/employee/add_employee_screen.dart';
import '../../../view/screen/employee/employee_detail_screen.dart';
import '../../../view/screen/employee/employee_settlement_screen.dart';
import '../../../data/data_source/remote/settlement_data/settlement_data.dart';
import '../../../view/screen/employee/terminated_employees_screen.dart';
import '../../../data/data_source/remote/employee_data/terminated_employee_data.dart';
import '../../../view/screen/attendance/attendance_screen.dart';
import '../../../view/screen/payroll/payroll_screen.dart';
import '../../../view/screen/leave/leave_screen.dart';
import '../../../view/screen/break/break_screen.dart';
import '../../../view/screen/loan/loans_screen.dart';
import '../../../data/data_source/remote/loan_data/loan_data.dart';
import '../../../view/screen/payroll/bulk_adjustments_screen.dart';
import '../../../view/screen/payroll/bulk_adjustment_create_screen.dart';
import '../../../view/screen/payroll/bulk_adjustment_detail_screen.dart';
import '../../../data/data_source/remote/bulk_adjustment_data/bulk_adjustment_data.dart';
import '../../../view/screen/audit/audit_log_screen.dart';
import '../../../data/data_source/remote/audit_data/audit_data.dart';
import '../../../view/screen/asset/assets_screen.dart';
import '../../../data/data_source/remote/asset_data/asset_data.dart';
import '../../../view/screen/branch/branch_screen.dart';
import '../../../view/screen/branch/branch_qr_poster_screen.dart';
import '../../../view/screen/report/report_screen.dart';
import '../../../view/screen/report/attendance_report_screen.dart';
import '../../../view/screen/report/payroll_report_screen.dart';
import '../../../view/screen/report/employees_report_screen.dart';
import '../../../view/screen/report/leaves_report_screen.dart';
import '../../../view/screen/settings/deduction_rules_screen.dart';
import '../../../view/screen/settings/attendance_method_screen.dart';
import '../../../view/screen/settings/company_settings_screen.dart';
import '../../../view/screen/settings/company_settings_hub_screen.dart';
import '../../../view/screen/settings/leave_settings_screen.dart';
import '../../../logic/controller/settings/leave_settings_controller.dart';
import '../../../view/screen/settings/leave_carryover_policies_screen.dart';
import '../../../logic/controller/settings/leave_carryover_policies_controller.dart';
import '../../../view/screen/settings/leave_encashments_screen.dart';
import '../../../logic/controller/settings/leave_encashments_controller.dart';
import '../../../view/screen/settings/account_settings_screen.dart';
import '../../../view/screen/settings/app_settings_screen.dart';
import '../../../view/screen/shift/shifts_screen.dart';
import '../../../view/screen/shift/assign_shift_screen.dart';
import '../../../view/screen/shift/shift_members_screen.dart';
import '../../../view/screen/schedule/weekly_schedule_screen.dart';
import '../../../data/data_source/remote/schedule_data/schedule_data.dart';
import '../../../logic/controller/schedule/schedule_controller.dart';
import '../../../view/screen/team/team_screen.dart';
import '../../../view/screen/team/invite_admin_screen.dart';
import '../../../view/screen/team/invitation_code_screen.dart';
import '../../../view/screen/employee/biometric_enrollment_screen.dart';
import '../../../view/screen/employee/employee_documents_screen.dart';
import '../../../view/screen/settings/required_documents_screen.dart';
import '../../../view/screen/settings/required_document_submissions_screen.dart';
import '../../../view/screen/report/documents_report_screen.dart';
import '../../../view/screen/category/categories_screen.dart';
import '../../../view/screen/category/category_employees_screen.dart';
import '../../../logic/controller/category/category_employees_controller.dart';
import '../../../view/screen/notification/notifications_screen.dart';
import '../../../view/screen/notification/notification_prefs_screen.dart';
import '../../../view/screen/settings/statutory_payroll_settings_screen.dart';
import '../../../view/screen/dashboard/status_employees_screen.dart';
import '../../../logic/controller/dashboard/status_employees_controller.dart';
import '../../../view/screen/dashboard/expiring_compliance_screen.dart';
import '../../../logic/controller/dashboard/expiring_compliance_controller.dart';
import '../../../data/data_source/remote/compliance_data/compliance_data.dart';
import '../../../data/data_source/remote/live_attendance_data/live_attendance_data.dart';
import '../../../data/data_source/remote/support_data/support_data.dart';
import '../../../logic/controller/support/support_controller.dart';
import '../../../view/screen/support/support_tickets_screen.dart';
import '../../../view/screen/support/support_chat_screen.dart';
import '../../../view/screen/support/new_ticket_screen.dart';
import '../../../logic/controller/notification/notification_controller.dart';
import '../../../logic/controller/settings/statutory_payroll_settings_controller.dart';
import '../../../data/data_source/remote/biometric_data/biometric_data.dart';
import '../../../data/data_source/remote/required_documents_data/required_documents_data.dart';
import '../../../data/data_source/remote/document_reports_data/document_reports_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../logic/controller/biometric/face_enrollment_controller.dart';
import '../../../logic/controller/shift/shift_controller.dart';
import '../../../logic/controller/category/category_controller.dart';
import '../../../logic/controller/team/team_controller.dart';
import '../../../data/data_source/remote/manager_data/manager_data.dart';
import '../../../logic/controller/report/attendance_report_controller.dart';
import '../../../logic/controller/report/payroll_report_controller.dart';
import '../../../logic/controller/report/employees_report_controller.dart';
import '../../../logic/controller/report/leaves_report_controller.dart';
import '../../../core/shared/layout/tab_shell.dart';
import '../../middleware/auth_middleware.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CRUD>(() => CRUD());
    Get.lazyPut<AuthData>(() => AuthData());
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    Get.put<DarkLightService>(DarkLightService(), permanent: true);
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<UpdateService>(UpdateService(), permanent: true);
  }
}

List<GetPage<dynamic>> getPages = [
  GetPage(
    name: AppRoutes.splash,
    page: () => const SplashScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.login,
    page: () => LoginScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.signup,
    page: () => SignUpScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.verifyEmail,
    page: () => const VerifyEmailScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.forgotPassword,
    page: () => ForgotPasswordScreen(),
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.onboarding,
    page: () => const OnboardingScreen(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.home,
    page: () => const MaintenanceGate(
      child: UpdateGate(
        child: TabShell(
          screens: [
            DashboardScreen(),
            EmployeesScreen(),
            AttendanceScreen(),
            PayrollScreen(),
            MoreScreen(),
          ],
        ),
      ),
    ),
    binding: HomeBinding(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.employeeAdd,
    page: () => const AddEmployeeScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<ShiftData>(() => ShiftData());
      Get.lazyPut<CategoryData>(() => CategoryData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.employeeDetail,
    page: () => const EmployeeDetailScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<EmployeeData>(() => EmployeeData());
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<DocumentData>(() => DocumentData());
      Get.lazyPut<RequiredDocumentsData>(() => RequiredDocumentsData());
      Get.lazyPut<PerformanceData>(() => PerformanceData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.leaveManage,
    page: () => const LeaveScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<EmployeeData>(() => EmployeeData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.breakManage,
    page: () => const BreakScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<BreakData>(() => BreakData());
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<CategoryData>(() => CategoryData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.assets,
    page: () => const AssetsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<AssetData>(() => AssetData());
      Get.lazyPut<EmployeeData>(() => EmployeeData());
      Get.lazyPut<CategoryData>(() => CategoryData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.loans,
    page: () => const LoansScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<LoanData>(() => LoanData());
      Get.lazyPut<EmployeeData>(() => EmployeeData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.bulkAdjustments,
    page: () => const BulkAdjustmentsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<BulkAdjustmentData>(() => BulkAdjustmentData());
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<CategoryData>(() => CategoryData());
      Get.lazyPut<EmployeeData>(() => EmployeeData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.bulkAdjustmentCreate,
    page: () => const BulkAdjustmentCreateScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<BulkAdjustmentData>(() => BulkAdjustmentData());
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<CategoryData>(() => CategoryData());
      Get.lazyPut<EmployeeData>(() => EmployeeData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.bulkAdjustmentDetail,
    page: () => const BulkAdjustmentDetailScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<BulkAdjustmentData>(() => BulkAdjustmentData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.auditLog,
    page: () => const AuditLogScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<AuditData>(() => AuditData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.branchManage,
    page: () => const BranchScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<BranchData>(() => BranchData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.branchQrPoster,
    page: () => const BranchQrPosterScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<BranchData>(() => BranchData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.reports,
    page: () => const ReportScreen(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.reportAttendance,
    page: () => const AttendanceReportScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ReportData>(() => ReportData());
      Get.lazyPut<AttendanceReportController>(
          () => AttendanceReportController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.reportPayroll,
    page: () => const PayrollReportScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ReportData>(() => ReportData());
      Get.lazyPut<PayrollReportController>(() => PayrollReportController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.reportEmployees,
    page: () => const EmployeesReportScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ReportData>(() => ReportData());
      Get.lazyPut<EmployeesReportController>(
          () => EmployeesReportController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.reportLeaves,
    page: () => const LeavesReportScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ReportData>(() => ReportData());
      Get.lazyPut<LeavesReportController>(() => LeavesReportController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.deductionRules,
    page: () => const DeductionRulesScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<DeductionRuleData>(() => DeductionRuleData());
      Get.lazyPut<DeductionRulesController>(() => DeductionRulesController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.attendanceMethod,
    page: () => const AttendanceMethodScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<CompanySettingsData>(() => CompanySettingsData());
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<ManagerData>(() => ManagerData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.companySettings,
    page: () => const CompanySettingsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<CompanySettingsData>(() => CompanySettingsData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.leaveSettings,
    page: () => const LeaveSettingsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<CompanySettingsData>(() => CompanySettingsData());
      Get.lazyPut<LeaveSettingsController>(() => LeaveSettingsController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.leaveCarryoverPolicies,
    page: () => const LeaveCarryoverPoliciesScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<CompanySettingsData>(() => CompanySettingsData());
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<CategoryData>(() => CategoryData());
      Get.lazyPut<LeaveCarryoverPoliciesController>(
          () => LeaveCarryoverPoliciesController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.leaveEncashments,
    page: () => const LeaveEncashmentsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<CompanySettingsData>(() => CompanySettingsData());
      Get.lazyPut<LeaveEncashmentsController>(
          () => LeaveEncashmentsController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.shifts,
    page: () => const ShiftsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ShiftData>(() => ShiftData());
      Get.lazyPut<ShiftController>(() => ShiftController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.assignShift,
    page: () => const AssignShiftScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ShiftData>(() => ShiftData());
      Get.lazyPut<ShiftController>(() => ShiftController());
      Get.lazyPut<EmployeeData>(() => EmployeeData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.shiftMembers,
    page: () => const ShiftMembersScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ShiftData>(() => ShiftData());
      Get.lazyPut<ShiftController>(() => ShiftController());
      Get.lazyPut<EmployeeData>(() => EmployeeData());
      Get.lazyPut<CategoryData>(() => CategoryData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.weeklySchedule,
    page: () => const WeeklyScheduleScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ScheduleData>(() => ScheduleData());
      Get.lazyPut<CompanySettingsData>(() => CompanySettingsData());
      Get.lazyPut<ScheduleController>(() => ScheduleController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.settingsCompany,
    page: () => const CompanySettingsHubScreen(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.settingsAccount,
    page: () => const AccountSettingsScreen(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.settingsApp,
    page: () => const AppSettingsScreen(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.team,
    page: () => const TeamScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ManagerData>(() => ManagerData());
      Get.lazyPut<TeamController>(() => TeamController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.inviteAdmin,
    page: () => const InviteAdminScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ManagerData>(() => ManagerData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.invitationCode,
    page: () => const InvitationCodeScreen(),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.biometricEnrollment,
    page: () => const BiometricEnrollmentScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<BiometricData>(() => BiometricData());
      Get.lazyPut<FaceEnrollmentController>(() => FaceEnrollmentController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.requiredDocuments,
    page: () => const RequiredDocumentsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<RequiredDocumentsData>(() => RequiredDocumentsData());
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<EmployeeData>(() => EmployeeData());
      Get.lazyPut<CategoryData>(() => CategoryData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.employeeDocuments,
    page: () => const EmployeeDocumentsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<DocumentData>(() => DocumentData());
      Get.lazyPut<RequiredDocumentsData>(() => RequiredDocumentsData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.requiredDocumentSubmissions,
    page: () => const RequiredDocumentSubmissionsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<RequiredDocumentsData>(() => RequiredDocumentsData());
      Get.lazyPut<DocumentData>(() => DocumentData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.documentsReport,
    page: () => const DocumentsReportScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<DocumentReportsData>(() => DocumentReportsData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.categories,
    page: () => const CategoriesScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<CategoryData>(() => CategoryData());
      Get.lazyPut<CategoryController>(() => CategoryController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.categoryEmployees,
    page: () => const CategoryEmployeesScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<EmployeeData>(() => EmployeeData());
      Get.lazyPut<CategoryEmployeesController>(
          () => CategoryEmployeesController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.notifications,
    page: () => const NotificationsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<NotificationController>(() => NotificationController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.notificationPrefs,
    page: () => const NotificationPrefsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<NotificationController>(() => NotificationController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.statusEmployees,
    page: () => const StatusEmployeesScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<LiveAttendanceData>(() => LiveAttendanceData());
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<ShiftData>(() => ShiftData());
      Get.lazyPut<CategoryData>(() => CategoryData());
      Get.lazyPut<StatusEmployeesController>(() => StatusEmployeesController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.expiringCompliance,
    page: () => const ExpiringComplianceScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ComplianceData>(() => ComplianceData());
      Get.lazyPut<ExpiringComplianceController>(
          () => ExpiringComplianceController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.statutoryPayrollSettings,
    page: () => const StatutoryPayrollSettingsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<CompanySettingsData>(() => CompanySettingsData());
      Get.lazyPut<StatutoryPayrollSettingsController>(
          () => StatutoryPayrollSettingsController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.support,
    page: () => const SupportTicketsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<SupportData>(() => SupportData());
      Get.lazyPut<SupportController>(() => SupportController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.supportChat,
    page: () => const SupportChatScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<SupportData>(() => SupportData());
      Get.lazyPut<SupportController>(() => SupportController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.supportNew,
    page: () => const NewTicketScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<SupportData>(() => SupportData());
      Get.lazyPut<SupportController>(() => SupportController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.employeeSettlement,
    page: () => const EmployeeSettlementScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<SettlementData>(() => SettlementData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.terminatedEmployees,
    page: () => const TerminatedEmployeesScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<TerminatedEmployeeData>(() => TerminatedEmployeeData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
];

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final canManageCompany = auth.user?.canManageCompanySettings ?? false;
    // Users with the deduction permission but no company-settings access (e.g.
    // HR) reach the company hub indirectly; give them a direct entry instead.
    final canManageDeductionRules =
        auth.user?.canManageDeductionRules ?? false;

    final canManageEmployees = auth.user?.canManageEmployees ?? false;
    final canManageLeaves = auth.user?.canManageLeaves ?? false;
    final canManagePayroll = auth.user?.canManagePayroll ?? false;
    final canManageAssets = auth.user?.canManageAssets ?? false;
    final canViewReports = auth.user?.canViewReports ?? false;
    // A section header must never render without at least one visible item.
    final showEmployees = canManageEmployees || canManageLeaves;
    final showFinance = canManagePayroll || canManageAssets;

    return Scaffold(
      appBar: AppBar(title: Text('more'.tr)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        children: [
          if (showEmployees) ...[
            _MoreSectionHeader(title: 'employees_and_time'.tr),
            if (canManageEmployees)
              _MenuTile(
                icon: Icons.calendar_view_week_outlined,
                title: 'weekly_schedule'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.weeklySchedule),
              ),
            if (canManageEmployees)
              _MenuTile(
                icon: Icons.event_note_outlined,
                title: 'leaves'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.leaveManage),
              ),
            if (canManageLeaves)
              _MenuTile(
                icon: Icons.coffee_outlined,
                title: 'break_requests'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.breakManage),
              ),
            if (canManageEmployees)
              _MenuTile(
                icon: Icons.person_off_outlined,
                title: 'terminated_employees'.tr,
                subtitle: 'terminated_employees_hint'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.terminatedEmployees),
              ),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (showFinance) ...[
            _MoreSectionHeader(title: 'finance_section'.tr),
            if (canManagePayroll)
              _MenuTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'loans'.tr,
                subtitle: 'loans_hint'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.loans),
              ),
            if (canManagePayroll)
              _MenuTile(
                icon: Icons.tune_outlined,
                title: 'bulk_adjustments'.tr,
                subtitle: 'bulk_adjustments_hint'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.bulkAdjustments),
              ),
            if (canManageAssets)
              _MenuTile(
                icon: Icons.inventory_2_outlined,
                title: 'assets'.tr,
                subtitle: 'assets_hint'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.assets),
              ),
            const SizedBox(height: AppSpacing.s4),
          ],
          if (canViewReports) ...[
            _MoreSectionHeader(title: 'reports'.tr),
            _MenuTile(
              icon: Icons.assessment_outlined,
              title: 'reports'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.reports),
            ),
            const SizedBox(height: AppSpacing.s4),
          ],
          _MoreSectionHeader(title: 'settings'.tr),
          if (canManageCompany)
            _MenuTile(
              icon: Icons.business_outlined,
              title: 'company_settings'.tr,
              subtitle: 'company_settings_hint'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.settingsCompany),
            ),
          if (!canManageCompany && canManageDeductionRules)
            _MenuTile(
              icon: Icons.tune_outlined,
              title: 'deduction_rules'.tr,
              subtitle: 'set_late_absence_rules'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.deductionRules),
            ),
          if (canManageCompany)
            _MenuTile(
              icon: Icons.history,
              title: 'activity_log'.tr,
              subtitle: 'activity_log_hint'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.auditLog),
            ),
          _MenuTile(
            icon: Icons.person_outline,
            title: 'my_account'.tr,
            subtitle: 'my_account_hint'.tr,
            onTap: () => Get.toNamed<void>(AppRoutes.settingsAccount),
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'app_settings'.tr,
            subtitle: 'app_settings_hint'.tr,
            onTap: () => Get.toNamed<void>(AppRoutes.settingsApp),
          ),
          _MenuTile(
            icon: Icons.support_agent_outlined,
            title: 'support_and_help'.tr,
            subtitle: 'support_hint'.tr,
            onTap: () => Get.toNamed<void>(AppRoutes.support),
          ),
          const SizedBox(height: AppSpacing.s5),
        ],
      ),
    );
  }
}

class _MoreSectionHeader extends StatelessWidget {
  final String title;
  const _MoreSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, AppSpacing.s3, AppSpacing.s4, AppSpacing.s2),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.04,
          color: AppColors.of(context).textTertiary,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListTile(
      leading: Icon(
        icon,
        color: colors.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.textTertiary,
              ),
            )
          : null,
      trailing: Icon(Icons.chevron_left, color: colors.textTertiary),
      onTap: onTap,
    );
  }
}
