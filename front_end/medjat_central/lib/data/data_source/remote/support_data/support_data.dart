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

  Future<Map<String, dynamic>> reply(int ticketId, String body) async {
    return await _crud.postData(AppLinks.supportReply, {
      'ticket_id': ticketId,
      'body': body,
    });
  }

  Future<Map<String, dynamic>> closeTicket(int ticketId, String action) async {
    return await _crud.postData(AppLinks.supportClose, {
      'ticket_id': ticketId,
      'action': action,
    });
  }
}
