import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class BreakData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> request({
    required String date,
    required String startTime,
    required String endTime,
    required String type,
    String? reason,
  }) async {
    final data = <String, dynamic>{
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'type': type,
    };
    if (reason != null && reason.trim().isNotEmpty) data['reason'] = reason.trim();
    return await _crud.postData(AppLinks.breakRequest, data);
  }

  Future<Map<String, dynamic>> myBreaks({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    return await _crud.getData(AppLinks.myBreaks, queryParameters: params);
  }

  Future<Map<String, dynamic>> cancel(int id) async {
    return await _crud.postData(AppLinks.breakCancel, {'break_id': id});
  }
}
