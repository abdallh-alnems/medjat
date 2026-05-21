import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class NotificationData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getNotifications({
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    return await _crud.getData(
      AppLinks.notifications,
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (unreadOnly) 'unread_only': '1',
      },
    );
  }

  Future<Map<String, dynamic>> markAsRead(int id) async {
    return await _crud.postData(AppLinks.notificationRead(id), {
      'id': id,
    });
  }

  Future<Map<String, dynamic>> getPrefs() async {
    return await _crud.getData(AppLinks.notificationPrefs);
  }

  Future<Map<String, dynamic>> savePrefs(Map<String, bool> prefs) async {
    return await _crud.postData(AppLinks.notificationPrefs, {
      'prefs': prefs,
    });
  }
}
