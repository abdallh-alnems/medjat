import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class EmployeeData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getEmployees({
    int? branchId,
    int? shiftId,
    int? categoryId,
    String? search,
    String? status,
    String? sort,
    String? dir,
    int? expiringWithin,
  }) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    if (shiftId != null) params['shift_id'] = shiftId;
    if (categoryId != null) params['category_id'] = categoryId;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (sort != null && sort.isNotEmpty) params['sort'] = sort;
    if (dir != null && dir.isNotEmpty) params['dir'] = dir;
    if (expiringWithin != null) params['expiring_within'] = expiringWithin;
    return await _crud.getData(AppLinks.employees, queryParameters: params);
  }

  Future<Map<String, dynamic>> getEmployee(int id) async {
    return await _crud.getData(AppLinks.employeeDetail(id));
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.employeeCreate, data);
  }

  Future<Map<String, dynamic>> updateEmployee(int id, Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.employeeUpdate, {...data, 'employee_id': id});
  }

  Future<Map<String, dynamic>> deleteEmployee(int id) async {
    return await _crud.postData(AppLinks.employeeDelete, {'id': id});
  }

  Future<Map<String, dynamic>> suspendEmployee(
    int employeeId, {
    required String reason,
    required String payMode,
    double? payPercentage,
    required String startDate,
    String? endDate,
  }) async {
    final data = <String, dynamic>{
      'employee_id': employeeId,
      'reason': reason,
      'pay_mode': payMode,
      'start_date': startDate,
    };
    if (payPercentage != null) data['pay_percentage'] = payPercentage;
    if (endDate != null && endDate.isNotEmpty) data['end_date'] = endDate;
    return await _crud.postData(AppLinks.employeeSuspend, data);
  }

  Future<Map<String, dynamic>> endSuspension(
    int employeeId, {
    String? endNote,
  }) async {
    final data = <String, dynamic>{'employee_id': employeeId};
    if (endNote != null && endNote.isNotEmpty) data['end_note'] = endNote;
    return await _crud.postData(AppLinks.employeeEndSuspension, data);
  }

  Future<Map<String, dynamic>> getSuspensions(int employeeId) async {
    return await _crud.getData(AppLinks.employeeSuspensions(employeeId));
  }

  Future<Map<String, dynamic>> getActivationCode(int employeeId) async {
    return await _crud.getData(AppLinks.employeeActivationCode(employeeId));
  }

  Future<Map<String, dynamic>> regenerateActivationCode(int employeeId) async {
    return await _crud.postData(AppLinks.employeeActivationCode(employeeId), {});
  }

  Future<Map<String, dynamic>> getAttendanceHistory(
    int employeeId, {
    String? month,
    String? from,
    String? to,
  }) async {
    return await _crud.getData(AppLinks.employeeAttendanceHistory(
      employeeId,
      month: month,
      from: from,
      to: to,
    ));
  }

  Future<Map<String, dynamic>> getFinancialSummary(int employeeId, String month) async {
    return await _crud.getData(AppLinks.employeeFinancialSummary(employeeId, month));
  }

  Future<Map<String, dynamic>> getYearToDate(int employeeId, int year) async {
    return await _crud.getData(AppLinks.employeeYearToDate(employeeId, year));
  }
}
