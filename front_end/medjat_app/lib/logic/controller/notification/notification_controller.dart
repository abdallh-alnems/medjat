import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/notification_data/notification_data.dart';

class NotificationController extends GetxController {
  final NotificationData _notificationData = Get.find<NotificationData>();

  StatusRequest status = StatusRequest.none;
  List<Map<String, dynamic>> notifications = [];
  int unreadCount = 0;
  Map<String, bool> prefs = {
    'late_absence': true,
    'missing_checkout': true,
    'document_expiry': true,
    'leave_events': true,
    'payroll_events': true,
  };

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
    loadPrefs();
  }

  Future<void> loadNotifications() async {
    status = StatusRequest.loading;
    update();

    final response = await _notificationData.list();
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        notifications = (data['notifications'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        unreadCount = (data['unread_count'] as int?) ?? 0;
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }

    update();
  }

  Future<void> markAsRead(int id) async {
    await _notificationData.markRead(id);
    final idx = notifications.indexWhere((n) => n['id'] == id);
    if (idx >= 0) {
      notifications[idx]['read_at'] = DateTime.now().toIso8601String();
      unreadCount = (unreadCount - 1).clamp(0, unreadCount);
      update();
    }
  }

  Future<void> loadPrefs() async {
    final response = await _notificationData.getPrefs();
    if (response['status'] == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      if (data?['prefs'] != null) {
        final p = data!['prefs'] as Map<String, dynamic>;
        prefs = p.map((k, v) => MapEntry(k, v as bool));
        update();
      }
    }
  }

  Future<void> updatePref(String key, bool value) async {
    prefs[key] = value;
    update();
    await _notificationData.updatePrefs(prefs);
  }
}
