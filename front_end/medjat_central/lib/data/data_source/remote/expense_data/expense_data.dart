import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class ExpenseData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getExpenses({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    return await _crud.getData(AppLinks.expenses, queryParameters: params);
  }

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.expenseCreate, data);
  }

  Future<Map<String, dynamic>> approveExpense(int id) async {
    return await _crud.postData(AppLinks.expenseApprove, {'id': id});
  }

  Future<Map<String, dynamic>> rejectExpense(int id, {String? reason}) async {
    return await _crud.postData(AppLinks.expenseReject, {
      'id': id,
      if (reason != null) 'rejection_reason': reason,
    });
  }

  Future<Map<String, dynamic>> reimburseExpense(int id) async {
    return await _crud.postData(AppLinks.expenseReimburse, {'id': id});
  }
}
