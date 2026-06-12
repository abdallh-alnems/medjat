import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class AdvanceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> request({
    required double totalAmount,
    required int installmentsCount,
    String? startMonth,
    String? reason,
  }) async {
    final data = <String, dynamic>{
      'total_amount': totalAmount,
      'installments_count': installmentsCount,
    };
    if (startMonth != null && startMonth.isNotEmpty) {
      data['start_month'] = startMonth;
    }
    if (reason != null && reason.trim().isNotEmpty) {
      data['reason'] = reason.trim();
    }
    return await _crud.postData(AppLinks.advanceRequest, data);
  }

  Future<Map<String, dynamic>> myAdvances({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    return await _crud.getData(AppLinks.myAdvances, queryParameters: params);
  }

  Future<Map<String, dynamic>> cancel(int id) async {
    return await _crud.postData(AppLinks.advanceCancel, {'loan_id': id});
  }
}
