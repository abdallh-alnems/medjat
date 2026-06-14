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
import 'local_notifications_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static bool _listenersReady = false;

  /// يُفعّل الإشعارات للموظف المسجّل دخوله فقط: يطلب الإذن، يجهّز المستمعين،
  /// ويسجّل التوكن. لا يُستدعى أبداً في وضع الكيوسك أو قبل تسجيل الدخول.
  static Future<void> enableForUser() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Attach listeners and register the token first so push delivery works
      // even if the permission prompt or local-notification setup fails.
      _setupListeners();

      try {
        await LocalNotificationsService.init();
        LocalNotificationsService.onTap = _routeByType;
      } catch (e) {
        debugPrint('LocalNotifications init error: $e');
      }

      await messaging.requestPermission();

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
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    // Show a real system notification (tray + sound) even while the app is open.
    LocalNotificationsService.show(title, body, message.data);
  }

  static void _handleMessageTap(RemoteMessage message) {
    _routeByType(message.data);
  }

  static void _routeByType(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';

    // Prefer routing by the id-bearing key in the payload: it is the most
    // reliable signal of which screen the notification is "about", regardless
    // of the exact `type` string the backend used.
    if (data.containsKey('leave_id')) {
      Get.toNamed<void>(AppRoutes.leaves);
      return;
    }
    if (data.containsKey('break_id')) {
      Get.toNamed<void>(AppRoutes.breaks);
      return;
    }
    if (data.containsKey('loan_id')) {
      Get.toNamed<void>(AppRoutes.advances);
      return;
    }
    if (data.containsKey('asset_id')) {
      Get.toNamed<void>(AppRoutes.myAssets);
      return;
    }
    if (data.containsKey('payroll_id')) {
      Get.toNamed<void>(AppRoutes.payroll);
      return;
    }
    if (data.containsKey('employee_document_id')) {
      Get.toNamed<void>(AppRoutes.myDocuments);
      return;
    }

    switch (type) {
      case 'leave':
      case 'leave_approved':
      case 'leave_rejected':
      case 'annual':
      case 'sick':
      case 'personal':
      case 'unpaid':
        Get.toNamed<void>(AppRoutes.leaves);
        break;
      case 'break':
      case 'break_approved':
      case 'break_rejected':
        Get.toNamed<void>(AppRoutes.breaks);
        break;
      case 'loan':
      case 'advance':
        Get.toNamed<void>(AppRoutes.advances);
        break;
      case 'payroll':
      case 'payroll_approved':
      case 'payroll_paid':
      case 'bonus_added':
      case 'deduction_added':
        Get.toNamed<void>(AppRoutes.payroll);
        break;
      case 'document':
      case 'document_expiry':
      case 'document_approved':
      case 'document_rejected':
      case 'document_removed':
        Get.toNamed<void>(AppRoutes.myDocuments);
        break;
      case 'asset':
        Get.toNamed<void>(AppRoutes.myAssets);
        break;
      default:
        Get.toNamed<void>(AppRoutes.notifications);
        break;
    }
  }
}
