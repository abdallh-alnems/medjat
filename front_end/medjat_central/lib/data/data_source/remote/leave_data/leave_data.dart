import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/app_links.dart';

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
      if (reason != null) 'reason': reason,
    });
  }

  Future<Map<String, dynamic>> createLeave(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.leaves, data);
  }
}
