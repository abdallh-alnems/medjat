import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class LeaveData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getLeaves({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    return await _crud.getData(AppLinks.leaves, queryParameters: params);
  }

  Future<Map<String, dynamic>> approveLeave(int id) async {
    return await _crud.postData(AppLinks.leaveApprove(id), {});
  }

  Future<Map<String, dynamic>> rejectLeave(int id, {String? reason}) async {
    return await _crud.postData(AppLinks.leaveReject(id), {
      if (reason != null) 'rejection_reason': reason,
    });
  }

  Future<Map<String, dynamic>> createLeave(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.leaveCreate, data);
  }

  Future<Map<String, dynamic>> createRecurringLeave(
      Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.leaveCreateRecurring, data);
  }

  Future<Map<String, dynamic>> leaveBalance(int employeeId,
      {int? year}) async {
    final params = <String, dynamic>{'employee_id': employeeId};
    if (year != null) params['year'] = year;
    return await _crud.getData(AppLinks.leaveBalance,
        queryParameters: params);
  }

  Future<Map<String, dynamic>> convertAbsenceToLeave({
    required int employeeId,
    required String date,
    required String type,
    required String reason,
  }) async {
    return await _crud.postData(AppLinks.leaveConvertAbsence, {
      'employee_id': employeeId,
      'date': date,
      'type': type,
      'reason': reason,
    });
  }
}
