import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class SupportData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> list({
    int page = 1,
    String? status,
    int? tenantId,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (status != null) params['status'] = status;
    if (tenantId != null) params['tenant_id'] = tenantId;
    return await _crud.getData(AppLinks.supportList, queryParameters: params);
  }

  Future<Map<String, dynamic>> messages(int ticketId, {int? afterId}) async {
    final params = <String, dynamic>{'ticket_id': ticketId};
    if (afterId != null) params['after_id'] = afterId;
    return await _crud.getData(AppLinks.supportMessages, queryParameters: params);
  }

  Future<Map<String, dynamic>> reply(int ticketId, String body) async {
    return await _crud.postData(AppLinks.supportReply, {
      'ticket_id': ticketId,
      'body': body,
    });
  }

  Future<Map<String, dynamic>> setStatus(int ticketId, String status) async {
    return await _crud.postData(AppLinks.supportStatus, {
      'ticket_id': ticketId,
      'status': status,
    });
  }
}
