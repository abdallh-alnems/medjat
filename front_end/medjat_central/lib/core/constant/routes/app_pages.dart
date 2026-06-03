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
import '../../../data/data_source/remote/performance_data/performance_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/document_data/document_data.dart';
import '../../../data/data_source/remote/deduction_rule_data/deduction_rule_data.dart';
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
import '../../../view/screen/attendance/attendance_screen.dart';
import '../../../view/screen/payroll/payroll_screen.dart';
import '../../../view/screen/leave/leave_screen.dart';
import '../../../view/screen/expense/expenses_screen.dart';
import '../../../view/screen/loan/loans_screen.dart';
import '../../../data/data_source/remote/expense_data/expense_data.dart';
import '../../../data/data_source/remote/loan_data/loan_data.dart';
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
import '../../../view/screen/station/stations_management_screen.dart';
import '../../../view/screen/station/recognition_logs_screen.dart';
import '../../../view/screen/employee/biometric_enrollment_screen.dart';
import '../../../view/screen/employee/employee_documents_screen.dart';
import '../../../view/screen/settings/required_documents_screen.dart';
import '../../../view/screen/report/documents_report_screen.dart';
import '../../../view/screen/category/categories_screen.dart';
import '../../../view/screen/notification/notifications_screen.dart';
import '../../../view/screen/notification/notification_prefs_screen.dart';
// TODO: statutory payroll settings screen not yet implemented; route disabled below.
// import '../../../view/screen/settings/statutory_payroll_settings_screen.dart';
import '../../../view/screen/letter/letters_hub_screen.dart';
import '../../../view/screen/letter/letter_template_edit_screen.dart';
import '../../../view/screen/dashboard/status_employees_screen.dart';
import '../../../logic/controller/dashboard/status_employees_controller.dart';
import '../../../view/screen/dashboard/expiring_compliance_screen.dart';
import '../../../logic/controller/dashboard/expiring_compliance_controller.dart';
import '../../../data/data_source/remote/compliance_data/compliance_data.dart';
import '../../../data/data_source/remote/live_attendance_data/live_attendance_data.dart';
import '../../../data/data_source/remote/letter_data/letter_data.dart';
import '../../../data/data_source/remote/support_data/support_data.dart';
import '../../../logic/controller/support/support_controller.dart';
import '../../../view/screen/support/support_tickets_screen.dart';
import '../../../view/screen/support/support_chat_screen.dart';
import '../../../view/screen/support/new_ticket_screen.dart';
import '../../../logic/controller/letter/letter_request_controller.dart';
import '../../../logic/controller/letter/letter_template_controller.dart';
import '../../../logic/controller/notification/notification_controller.dart';
// import '../../../logic/controller/settings/statutory_payroll_settings_controller.dart';
import '../../../data/data_source/remote/station_data/station_data.dart';
import '../../../data/data_source/remote/biometric_data/biometric_data.dart';
import '../../../data/data_source/remote/required_documents_data/required_documents_data.dart';
import '../../../data/data_source/remote/document_reports_data/document_reports_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../logic/controller/station/stations_controller.dart';
import '../../../logic/controller/station/station_settings_controller.dart';
import '../../../logic/controller/station/recognition_logs_controller.dart';
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
    name: AppRoutes.assets,
    page: () => const AssetsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<AssetData>(() => AssetData());
      Get.lazyPut<EmployeeData>(() => EmployeeData());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.expenses,
    page: () => const ExpensesScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<ExpenseData>(() => ExpenseData());
      Get.lazyPut<EmployeeData>(() => EmployeeData());
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
    name: AppRoutes.stationsManagement,
    page: () => const StationsManagementScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<StationData>(() => StationData());
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<StationsController>(() => StationsController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.stationSettings,
    page: () => const _StationSettingsWrapper(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<StationData>(() => StationData());
      Get.lazyPut<BranchData>(() => BranchData());
      Get.lazyPut<StationSettingsController>(() => StationSettingsController());
    }),
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
    name: AppRoutes.recognitionLogs,
    page: () => const RecognitionLogsScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<StationData>(() => StationData());
      Get.lazyPut<RecognitionLogsController>(() => RecognitionLogsController());
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
    name: AppRoutes.letters,
    page: () => const LettersHubScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<LetterData>(() => LetterData());
      Get.lazyPut<EmployeeData>(() => EmployeeData());
      Get.lazyPut<LetterTemplateController>(() => LetterTemplateController());
      Get.lazyPut<LetterRequestController>(() => LetterRequestController());
    }),
    middlewares: [AuthMiddleware()],
    transition: Transition.fadeIn,
    transitionDuration: AppMotion.transition,
  ),
  GetPage(
    name: AppRoutes.letterTemplateEdit,
    page: () => const LetterTemplateEditScreen(),
    binding: BindingsBuilder<void>(() {
      Get.lazyPut<LetterData>(() => LetterData());
      Get.lazyPut<LetterTemplateController>(() => LetterTemplateController());
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
  // TODO: statutory payroll settings screen/controller not yet implemented.
  // GetPage(
  //   name: AppRoutes.statutoryPayrollSettings,
  //   page: () => const StatutoryPayrollSettingsScreen(),
  //   binding: BindingsBuilder<void>(() {
  //     Get.lazyPut<StatutoryPayrollSettingsController>(
  //         () => StatutoryPayrollSettingsController());
  //   }),
  //   middlewares: [AuthMiddleware()],
  //   transition: Transition.fadeIn,
  //   transitionDuration: AppMotion.transition,
  // ),
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
];

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final canManageCompany = auth.user?.canManageCompanySettings ?? false;

    return Scaffold(
      appBar: AppBar(title: Text('more'.tr)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        children: [
          _MoreSectionHeader(title: 'management'.tr),
          if (auth.user?.canManageEmployees == true)
            _MenuTile(
              icon: Icons.schedule_outlined,
              title: 'shifts'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.shifts),
            ),
          if (auth.user?.canManageEmployees == true)
            _MenuTile(
              icon: Icons.calendar_view_week_outlined,
              title: 'weekly_schedule'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.weeklySchedule),
            ),
          if (auth.user?.canManageEmployees == true)
            _MenuTile(
              icon: Icons.event_note_outlined,
              title: 'leaves'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.leaveManage),
            ),
          if (auth.user?.canManageDocuments == true)
            _MenuTile(
              icon: Icons.description_outlined,
              title: 'letters'.tr,
              subtitle: 'letters_hint'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.letters),
            ),
          if (auth.user?.canManagePayroll == true)
            _MenuTile(
              icon: Icons.receipt_long_outlined,
              title: 'expenses'.tr,
              subtitle: 'expenses_hint'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.expenses),
            ),
          if (auth.user?.canManagePayroll == true)
            _MenuTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'loans'.tr,
              subtitle: 'loans_hint'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.loans),
            ),
          if (auth.user?.canManageAssets == true)
            _MenuTile(
              icon: Icons.inventory_2_outlined,
              title: 'assets'.tr,
              subtitle: 'assets_hint'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.assets),
            ),
          if (auth.user?.canManageBranches == true)
            _MenuTile(
              icon: Icons.account_tree_outlined,
              title: 'branches'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.branchManage),
            ),
          if (auth.user?.canViewReports == true)
            _MenuTile(
              icon: Icons.assessment_outlined,
              title: 'reports'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.reports),
            ),
          const SizedBox(height: AppSpacing.s4),
          _MoreSectionHeader(title: 'settings'.tr),
          if (canManageCompany)
            _MenuTile(
              icon: Icons.business_outlined,
              title: 'company_settings'.tr,
              subtitle: 'company_settings_hint'.tr,
              onTap: () => Get.toNamed<void>(AppRoutes.settingsCompany),
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

class _StationSettingsWrapper extends StatelessWidget {
  const _StationSettingsWrapper();

  @override
  Widget build(BuildContext context) {
    final branchId = (Get.arguments as Map<String, dynamic>?)?['branch_id'] as int? ?? 0;
    final ctrl = Get.put(StationSettingsController());
    ctrl.init(branchId);
    return _StationSettingsScreen(ctrl: ctrl);
  }
}

class _StationSettingsScreen extends StatelessWidget {
  final StationSettingsController ctrl;
  const _StationSettingsScreen({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('station_section_title'.tr)),
      body: GetBuilder<StationSettingsController>(
        builder: (_) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: Text('station_enabled'.tr,
                      style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14, fontWeight: FontWeight.w500)),
                  value: ctrl.settings.enabled,
                  onChanged: (v) => ctrl.saveSettings(enabled: v),
                  activeColor: colors.brand,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text('station_methods_label'.tr, style: AppTextStyles.h3(context)),
                const SizedBox(height: AppSpacing.s2),
                ...['face_only', 'fingerprint_only', 'both_available'].map((m) {
                  final label = m == 'face_only'
                      ? 'station_face_only'.tr
                      : m == 'fingerprint_only'
                          ? 'station_fingerprint_only'.tr
                          : 'station_both'.tr;
                  return RadioListTile<String>(
                    title: Text(label, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 13)),
                    value: m,
                    groupValue: ctrl.settings.methods,
                    onChanged: (v) => ctrl.saveSettings(methods: v),
                    activeColor: colors.brand,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }),
                const SizedBox(height: AppSpacing.s4),
                Text('station_gps_radius'.tr, style: AppTextStyles.h3(context)),
                const SizedBox(height: AppSpacing.s2),
                Slider(
                  value: ctrl.settings.gpsRadiusMeters.toDouble(),
                  min: 10,
                  max: 200,
                  divisions: 19,
                  label: '${ctrl.settings.gpsRadiusMeters}m',
                  onChanged: (v) => ctrl.saveSettings(gpsRadius: v.toInt()),
                  activeColor: colors.brand,
                ),
                const SizedBox(height: AppSpacing.s3),
                Text('station_confidence'.tr, style: AppTextStyles.h3(context)),
                const SizedBox(height: AppSpacing.s2),
                Slider(
                  value: ctrl.settings.confidenceThreshold,
                  min: 0.5,
                  max: 1.0,
                  divisions: 10,
                  label: ctrl.settings.confidenceThreshold.toStringAsFixed(2),
                  onChanged: (v) => ctrl.saveSettings(confidence: v),
                  activeColor: colors.brand,
                ),
                const SizedBox(height: AppSpacing.s3),
                SwitchListTile(
                  title: Text('station_anti_spoofing'.tr,
                      style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14)),
                  value: ctrl.settings.antiSpoofing,
                  onChanged: (v) => ctrl.saveSettings(antiSpoofing: v),
                  activeColor: colors.brand,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSpacing.s4),
                if (!ctrl.settings.hasAdminPin) ...[
                  Text('admin_pin'.tr, style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s2),
                  ElevatedButton.icon(
                    onPressed: () => _showPinDialog(context),
                    icon: const Icon(Icons.pin_outlined),
                    label: Text('set_admin_pin'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.s5),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Get.toNamed<void>(AppRoutes.stationsManagement),
                        icon: const Icon(Icons.devices_outlined, size: 18),
                        label: Text('manage_devices'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontWeight: FontWeight.w500)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.brand,
                          side: BorderSide(color: colors.brand),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Get.toNamed<void>(AppRoutes.recognitionLogs),
                        icon: const Icon(Icons.history_outlined, size: 18),
                        label: Text('view_recognition_logs'.tr, style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontWeight: FontWeight.w500)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.brand,
                          side: BorderSide(color: colors.brand),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPinDialog(BuildContext context) {
    final pinCtrl = TextEditingController();
    Get.dialog<void>(
      AlertDialog(
        title: Text('admin_pin'.tr),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: '******'),
        ),
        actions: [
          TextButton(onPressed: () => Get.back<void>(), child: Text('cancel'.tr)),
          ElevatedButton(
            onPressed: () {
              if (pinCtrl.text.isNotEmpty) {
                Get.back<void>();
                ctrl.saveSettings(adminPin: pinCtrl.text);
              }
            },
            child: Text('save'.tr),
          ),
        ],
      ),
    );
  }
}
