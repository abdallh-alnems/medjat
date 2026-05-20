import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class PayrollData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getPayrolls({int? branchId}) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.payroll, queryParameters: params);
  }

  Future<Map<String, dynamic>> getPayrollMonth(int month, int year, {int? branchId}) async {
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final params = <String, dynamic>{'month': monthStr};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.payroll, queryParameters: params);
  }

  Future<Map<String, dynamic>> approvePayroll(int id) async {
    return await _crud.postData(AppLinks.payrollApprove(id), {});
  }

  Future<Map<String, dynamic>> addManualDeduction({
    required int employeeId,
    required num amount,
    required String reason,
  }) async {
    return await _crud.postData(AppLinks.deductionManualAdd, {
      'employee_id': employeeId,
      'amount': amount,
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>> addManualBonus({
    required int employeeId,
    required num amount,
    required String reason,
  }) async {
    return await _crud.postData(AppLinks.bonusManualAdd, {
      'employee_id': employeeId,
      'amount': amount,
      'reason': reason,
    });
  }
}
