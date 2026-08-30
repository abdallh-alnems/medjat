import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

/// Announcements. [audience] is `admins`, `employees` or `all` — without it the
/// send reaches company managers only, which is what used to happen silently.
class NotificationData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> sendAll({
    required String title,
    required String body,
    String audience = 'admins',
  }) async {
    return await _crud.postData(AppLinks.notificationSendAll, {
      'title': title,
      'body': body,
      'audience': audience,
    });
  }

  Future<Map<String, dynamic>> sendToTenant({
    required int tenantId,
    required String title,
    required String body,
    String audience = 'admins',
  }) async {
    return await _crud.postData(AppLinks.notificationSendTenant, {
      'tenant_id': tenantId,
      'title': title,
      'body': body,
      'audience': audience,
    });
  }
}
