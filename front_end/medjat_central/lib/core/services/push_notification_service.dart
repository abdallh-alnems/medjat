import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/id/app_links.dart';
import '../constant/routes/app_routes.dart';
import '../class/crud.dart';
import 'local_notifications_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static Future<void> init() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Attach listeners first so foreground handling always works, even if the
      // permission prompt or local-notification setup below fails.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      try {
        await LocalNotificationsService.init();
        LocalNotificationsService.onTap = _handleData;
      } catch (e) {
        debugPrint('LocalNotifications init error: $e');
      }

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      await _registerToken();

      messaging.onTokenRefresh.listen((token) {
        _sendTokenToBackend(token);
      });
    } catch (e) {
      debugPrint('PushNotificationService init error: $e');
    }
  }

  static Future<void> _registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('PushNotificationService registerToken error: $e');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      final crud = Get.find<CRUD>();
      await crud.postData(
        AppLinks.updateFcmToken,
        {
          'fcm_token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
          'device_id': token.hashCode.toRadixString(16),
        },
      );
    } catch (e) {
      debugPrint('PushNotificationService sendToken error: $e');
    }
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] as String?;
    final body = notification?.body ?? message.data['body'] as String?;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    // Show a real system notification (tray + sound) even while the app is open.
    LocalNotificationsService.show(title, body, message.data);
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    _handleData(message.data);
  }

  static void _handleData(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    if (type == 'support') {
      final ticketId = int.tryParse(data['ticket_id']?.toString() ?? '');
      if (ticketId != null) {
        _navigateToSupportChat(ticketId);
      }
    }
  }

  static void _navigateToSupportChat(int ticketId) {
    Get.toNamed<void>(
      AppRoutes.supportChat,
      arguments: {'ticket_id': ticketId},
    );
  }
}
