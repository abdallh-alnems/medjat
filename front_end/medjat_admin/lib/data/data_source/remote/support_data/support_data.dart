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

  /// [attachmentBase64] is a raw base64 image/PDF; the backend re-derives the
  /// type from the bytes and stores it outside any public directory. A reply
  /// may be an attachment with no text.
  Future<Map<String, dynamic>> reply(
    int ticketId,
    String body, {
    String? attachmentBase64,
    String? attachmentName,
  }) async {
    return await _crud.postData(AppLinks.supportReply, {
      'ticket_id': ticketId,
      'body': body,
      'attachment': ?attachmentBase64,
      'attachment_name': ?attachmentName,
    });
  }

  Future<Map<String, dynamic>> setStatus(int ticketId, String status) async {
    return await _crud.postData(AppLinks.supportStatus, {
      'ticket_id': ticketId,
      'status': status,
    });
  }
}
