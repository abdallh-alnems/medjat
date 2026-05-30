import 'package:get/get.dart';
import '../../../data/data_source/remote/dashboard_data/dashboard_data.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';
import '../../../data/data_source/remote/leave_data/leave_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/report_data/report_data.dart';
import '../../../data/data_source/remote/document_data/document_data.dart';
import '../../../data/data_source/remote/shift_data/shift_data.dart';
import '../../../data/data_source/remote/schedule_data/schedule_data.dart';
import '../../../data/data_source/remote/manager_data/manager_data.dart';
import '../../../data/data_source/remote/live_attendance_data/live_attendance_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/data_source/remote/letter_data/letter_data.dart';
import '../controller/dashboard/dashboard_controller.dart';
import '../controller/employee/employee_controller.dart';
import '../controller/attendance/attendance_controller.dart';
import '../controller/payroll/payroll_controller.dart';
import '../controller/leave/leave_controller.dart';
import '../controller/branch/branch_controller.dart';
import '../controller/settings/settings_controller.dart';
import '../controller/shift/shift_controller.dart';
import '../controller/schedule/schedule_controller.dart';
import '../controller/live_attendance/live_attendance_controller.dart';
import '../controller/category/category_controller.dart';
import '../../../core/shared/layout/tab_shell.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // fenix: true keeps the lazy factory alive after the instance is disposed,
    // so the controller/data source is rebuilt automatically on the next
    // Get.find instead of throwing "not found" when a screen is re-entered.
    Get.lazyPut<DashboardData>(() => DashboardData(), fenix: true);
    Get.lazyPut<EmployeeData>(() => EmployeeData(), fenix: true);
    Get.lazyPut<AttendanceData>(() => AttendanceData(), fenix: true);
    Get.lazyPut<PayrollData>(() => PayrollData(), fenix: true);
    Get.lazyPut<LeaveData>(() => LeaveData(), fenix: true);
    Get.lazyPut<BranchData>(() => BranchData(), fenix: true);
    Get.lazyPut<ReportData>(() => ReportData(), fenix: true);
    Get.lazyPut<DocumentData>(() => DocumentData(), fenix: true);
    Get.lazyPut<ShiftData>(() => ShiftData(), fenix: true);
    Get.lazyPut<ScheduleData>(() => ScheduleData(), fenix: true);
    Get.lazyPut<ManagerData>(() => ManagerData(), fenix: true);
    Get.lazyPut<LiveAttendanceData>(() => LiveAttendanceData(), fenix: true);
    Get.lazyPut<CategoryData>(() => CategoryData(), fenix: true);
    // Employee detail's financial tab issues letters/certificates on demand.
    Get.lazyPut<LetterData>(() => LetterData(), fenix: true);
    Get.lazyPut<DashboardController>(() => DashboardController(), fenix: true);
    Get.lazyPut<LiveAttendanceController>(() => LiveAttendanceController(),
        fenix: true);
    Get.lazyPut<EmployeeController>(() => EmployeeController(), fenix: true);
    Get.lazyPut<AttendanceController>(() => AttendanceController(),
        fenix: true);
    Get.lazyPut<PayrollController>(() => PayrollController(), fenix: true);
    Get.lazyPut<LeaveController>(() => LeaveController(), fenix: true);
    Get.lazyPut<BranchController>(() => BranchController(), fenix: true);
    Get.lazyPut<SettingsController>(() => SettingsController(), fenix: true);
    Get.lazyPut<ShiftController>(() => ShiftController(), fenix: true);
    Get.lazyPut<CategoryController>(() => CategoryController(), fenix: true);
    Get.lazyPut<ScheduleController>(() => ScheduleController(), fenix: true);
    Get.lazyPut<TabNavController>(() => TabNavController(), fenix: true);
  }
}
