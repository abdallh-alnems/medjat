import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/id/app_links.dart';
import '../constant/routes/app_routes.dart';
import '../class/crud.dart';

class PushNotificationService {
  PushNotificationService._();

  static Future<void> init() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('PushNotificationService: permission denied');
        return;
      }

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

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
    if (notification == null) return;

    Get.snackbar(
      notification.title ?? '',
      notification.body ?? '',
      snackPosition: SnackPosition.TOP,
      duration: const Duration(seconds: 5),
      margin: const EdgeInsets.all(12),
      mainButton: _actionButton(message.data),
    );
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    _handleData(message.data);
  }

  static TextButton? _actionButton(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    if (type == 'support') {
      final ticketId = int.tryParse(data['ticket_id']?.toString() ?? '');
      if (ticketId != null) {
        return TextButton(
          onPressed: () => _navigateToSupportChat(ticketId),
          child: const Text('Open'),
        );
      }
    }
    return null;
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
