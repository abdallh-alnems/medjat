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

  Future<Map<String, dynamic>> getBalance({int? year}) async {
    final params = <String, dynamic>{};
    if (year != null) params['year'] = year.toString();
    return await _crud.getData(AppLinks.leaveBalance, queryParameters: params);
  }
}
