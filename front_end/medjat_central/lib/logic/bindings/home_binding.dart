import 'package:get/get.dart';
import '../../../data/data_source/remote/dashboard_data/dashboard_data.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';
import '../../../data/data_source/remote/leave_data/leave_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/report_data/report_data.dart';
import '../controller/dashboard/dashboard_controller.dart';
import '../controller/employee/employee_controller.dart';
import '../controller/attendance/attendance_controller.dart';
import '../controller/payroll/payroll_controller.dart';
import '../controller/leave/leave_controller.dart';
import '../controller/branch/branch_controller.dart';
import '../controller/settings/settings_controller.dart';
import '../../../core/shared/layout/tab_shell.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardData>(() => DashboardData());
    Get.lazyPut<EmployeeData>(() => EmployeeData());
    Get.lazyPut<AttendanceData>(() => AttendanceData());
    Get.lazyPut<PayrollData>(() => PayrollData());
    Get.lazyPut<LeaveData>(() => LeaveData());
    Get.lazyPut<BranchData>(() => BranchData());
    Get.lazyPut<ReportData>(() => ReportData());
    Get.lazyPut<DashboardController>(() => DashboardController());
    Get.lazyPut<EmployeeController>(() => EmployeeController());
    Get.lazyPut<AttendanceController>(() => AttendanceController());
    Get.lazyPut<PayrollController>(() => PayrollController());
    Get.lazyPut<LeaveController>(() => LeaveController());
    Get.lazyPut<BranchController>(() => BranchController());
    Get.lazyPut<SettingsController>(() => SettingsController());
    Get.lazyPut<TabNavController>(() => TabNavController());
  }
}
