import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class ReportData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getAttendanceReport({
    required String startDate,
    required String endDate,
    int? branchId,
  }) async {
    final params = <String, dynamic>{
      'start_date': startDate,
      'end_date': endDate,
    };
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.reportAttendance,
        queryParameters: params);
  }

  Future<Map<String, dynamic>> getPayrollReport({
    required String month,
    int? branchId,
  }) async {
    final params = <String, dynamic>{'month': month};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.reportPayroll,
        queryParameters: params);
  }

  Future<Map<String, dynamic>> getEmployeesReport({
    int? branchId,
  }) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.reportEmployees,
        queryParameters: params);
  }

  Future<Map<String, dynamic>> getLeavesReport({
    required String startDate,
    required String endDate,
    int? branchId,
    String? status,
  }) async {
    final params = <String, dynamic>{
      'start_date': startDate,
      'end_date': endDate,
    };
    if (branchId != null) params['branch_id'] = branchId;
    if (status != null) params['status'] = status;
    return await _crud.getData(AppLinks.reportLeaves,
        queryParameters: params);
  }
}
