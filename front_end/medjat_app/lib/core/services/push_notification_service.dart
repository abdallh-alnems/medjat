import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constant/id/app_links.dart';
import '../constant/routes/app_routes.dart';
import '../class/crud.dart';
import '../services/token_storage_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static bool _listenersReady = false;

  /// يُفعّل الإشعارات للموظف المسجّل دخوله فقط: يطلب الإذن، يجهّز المستمعين،
  /// ويسجّل التوكن. لا يُستدعى أبداً في وضع الكيوسك أو قبل تسجيل الدخول.
  static Future<void> enableForUser() async {
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

      _setupListeners();
      await registerTokenNow();
    } catch (e) {
      debugPrint('PushNotificationService enableForUser error: $e');
    }
  }

  static void _setupListeners() {
    if (_listenersReady) return;
    _listenersReady = true;

    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageTap(message);
      }
    });

    messaging.onTokenRefresh.listen((token) {
      _sendTokenIfReady(token);
    });
  }

  static Future<void> registerTokenNow() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('PushNotificationService registerTokenNow error: $e');
    }
  }

  static Future<void> _sendTokenIfReady(String token) async {
    try {
      final userData = await TokenStorageService.getUserData();
      if (userData == null) return;
      final json = jsonDecode(userData) as Map<String, dynamic>;
      final tenantId = json['tenant_id'];
      if (tenantId == null || tenantId == 0) return;
      await _sendTokenToBackend(token);
    } catch (e) {
      debugPrint('PushNotificationService sendTokenIfReady error: $e');
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      final crud = Get.find<CRUD>();
      await crud.postData(
        AppLinks.registerFcm,
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
    );
  }

  static void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type']?.toString() ?? '';

    switch (type) {
      case 'leave':
      case 'leave_approved':
      case 'leave_rejected':
        Get.toNamed<void>(AppRoutes.leaves);
        break;
      case 'payroll':
      case 'payroll_approved':
        Get.toNamed<void>(AppRoutes.payroll);
        break;
      case 'document':
      case 'document_expiry':
        Get.toNamed<void>(AppRoutes.myDocuments);
        break;
      default:
        Get.toNamed<void>(AppRoutes.notifications);
        break;
    }
  }
}
