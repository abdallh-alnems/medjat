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
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.payrollMonth(month, year), queryParameters: params);
  }

  Future<Map<String, dynamic>> approvePayroll(int id) async {
    return await _crud.postData(AppLinks.payrollApprove(id), {});
  }
}
