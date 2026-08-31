import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class SupportData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> listTickets({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    return await _crud.getData(
      AppLinks.supportTickets,
      queryParameters: {
        'status': ?status,
        'page': page,
        'limit': limit,
      },
    );
  }

  Future<Map<String, dynamic>> createTicket({
    required String subject,
    required String category,
    required String priority,
    required String body,
  }) async {
    return await _crud.postData(AppLinks.supportCreate, {
      'subject': subject,
      'category': category,
      'priority': priority,
      'body': body,
    });
  }

  Future<Map<String, dynamic>> getMessages(int ticketId, {int? afterId}) async {
    return await _crud.getData(
      AppLinks.supportMessages(ticketId, afterId: afterId),
    );
  }

  /// [attachmentBase64] is a raw base64 image/PDF; the backend re-derives the
  /// type from the bytes. A reply may be an attachment with no text.
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

  /// Raw bytes of one attachment, fetched with auth headers.
  Future<Map<String, dynamic>> attachmentBytes(int messageId) async {
    return await _crud.getBytes(AppLinks.supportAttachment(messageId));
  }

  Future<Map<String, dynamic>> closeTicket(int ticketId, String action) async {
    return await _crud.postData(AppLinks.supportClose, {
      'ticket_id': ticketId,
      'action': action,
    });
  }
}
