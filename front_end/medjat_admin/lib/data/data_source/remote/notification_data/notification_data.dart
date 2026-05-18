import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class NotificationData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> sendAll({
    required String title,
    required String body,
  }) async {
    return await _crud.postData(AppLinks.notificationSendAll, {
      'title': title,
      'body': body,
    });
  }

  Future<Map<String, dynamic>> sendToTenant({
    required int tenantId,
    required String title,
    required String body,
  }) async {
    return await _crud.postData(AppLinks.notificationSendTenant, {
      'tenant_id': tenantId,
      'title': title,
      'body': body,
    });
  }
}
