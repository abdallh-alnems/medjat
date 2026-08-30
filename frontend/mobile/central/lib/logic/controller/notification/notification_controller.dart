import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/notification_data/notification_data.dart';

class NotificationController extends GetxController {
  final NotificationData _data = NotificationData();

  final notifications = <Map<String, dynamic>>[].obs;
  final unreadCount = 0.obs;
  final isLoading = false.obs;
  final prefs = <String, bool>{
    'late_absence': true,
    'missing_checkout': true,
    'document_expiry': true,
    'leave_events': true,
    'payroll_events': true,
  }.obs;
  final prefsLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    try {
      final response = await _data.getNotifications();
      if (response['status'] == StatusRequest.success) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          final payload = data['data'] ?? data;
          if (payload is Map<String, dynamic>) {
            final rawList = payload['notifications'];
            if (rawList is List) {
              notifications.value = rawList
                  .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
            }
            final rawCount = payload['unread_count'];
            if (rawCount is int) {
              unreadCount.value = rawCount;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationController load error: $e');
    }
    isLoading.value = false;
  }

  Future<void> markAsRead(int id) async {
    try {
      await _data.markAsRead(id);
      final idx = notifications.indexWhere((n) => n['id'] == id);
      if (idx != -1) {
        notifications[idx]['read_at'] = DateTime.now().toIso8601String();
        notifications.refresh();
        if (unreadCount.value > 0) unreadCount.value--;
      }
    } catch (e) {
      debugPrint('NotificationController markRead error: $e');
    }
  }

  Future<void> loadPrefs() async {
    prefsLoading.value = true;
    try {
      final response = await _data.getPrefs();
      if (response['status'] == StatusRequest.success) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          final payload = data['data'] ?? data;
          if (payload is Map<String, dynamic> && payload['prefs'] != null) {
            final raw = payload['prefs'];
            if (raw is Map) {
              final loaded = Map<String, dynamic>.from(raw);
              prefs.value = {
                'late_absence': (loaded['late_absence'] as bool?) ?? true,
                'missing_checkout': (loaded['missing_checkout'] as bool?) ?? true,
                'document_expiry': (loaded['document_expiry'] as bool?) ?? true,
                'leave_events': (loaded['leave_events'] as bool?) ?? true,
                'payroll_events': (loaded['payroll_events'] as bool?) ?? true,
              };
            }
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationController loadPrefs error: $e');
    }
    prefsLoading.value = false;
  }

  Future<void> savePrefs() async {
    prefsLoading.value = true;
    try {
      await _data.savePrefs(Map<String, bool>.from(prefs));
      Get.snackbar('done'.tr, '', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      debugPrint('NotificationController savePrefs error: $e');
    }
    prefsLoading.value = false;
  }
}
