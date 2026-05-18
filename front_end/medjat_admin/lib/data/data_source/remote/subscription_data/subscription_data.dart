import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class SubscriptionData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> list({int page = 1}) async {
    return await _crud.postData(AppLinks.subscriptions, {'page': page});
  }

  Future<Map<String, dynamic>> update({
    required int tenantId,
    String? status,
    int? planId,
    String? startDate,
    String? endDate,
  }) async {
    final data = <String, dynamic>{'tenant_id': tenantId};
    if (status != null) data['status'] = status;
    if (planId != null) data['plan_id'] = planId;
    if (startDate != null) data['start_date'] = startDate;
    if (endDate != null) data['end_date'] = endDate;
    return await _crud.postData(AppLinks.subscriptionUpdate, data);
  }
}
