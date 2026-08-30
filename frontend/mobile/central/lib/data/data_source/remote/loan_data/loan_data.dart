import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class LoanData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getLoans({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    return await _crud.getData(AppLinks.loans, queryParameters: params);
  }

  Future<Map<String, dynamic>> getLoan(int id) async {
    return await _crud.getData(AppLinks.loanDetail(id));
  }

  Future<Map<String, dynamic>> createLoan(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.loanCreate, data);
  }

  Future<Map<String, dynamic>> approveLoan(int id) async {
    return await _crud.postData(AppLinks.loanApprove, {'id': id});
  }

  Future<Map<String, dynamic>> cancelLoan(int id) async {
    return await _crud.postData(AppLinks.loanCancel, {'id': id});
  }
}
