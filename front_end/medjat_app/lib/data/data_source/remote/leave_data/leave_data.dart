import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class LeaveData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> apply({
    required String date,
    required String type,
    String? reason,
    String? startDate,
    String? endDate,
  }) async {
    final data = <String, dynamic>{
      'date': date,
      'type': type,
    };
    if (reason != null) data['reason'] = reason;
    if (startDate != null) data['start_date'] = startDate;
    if (endDate != null) data['end_date'] = endDate;
    return await _crud.postData(AppLinks.leaveApply, data);
  }

  Future<Map<String, dynamic>> myLeaves({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    return await _crud.getData(AppLinks.myLeaves, queryParameters: params);
  }

  Future<Map<String, dynamic>> cancel(int id) async {
    return await _crud.postData(AppLinks.leaveCancel, {'leave_id': id});
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required String type,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    final data = <String, dynamic>{
      'leave_id': id,
      'type': type,
      'date': startDate,
      'start_date': startDate,
      'end_date': endDate,
    };
    if (reason != null) data['reason'] = reason;
    return await _crud.postData(AppLinks.leaveUpdate, data);
  }

  Future<Map<String, dynamic>> getBalance({int? year}) async {
    final params = <String, dynamic>{};
    if (year != null) params['year'] = year.toString();
    return await _crud.getData(AppLinks.leaveBalance, queryParameters: params);
  }
}
