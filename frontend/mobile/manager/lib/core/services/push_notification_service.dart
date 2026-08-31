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

      await messaging.requestPermission();

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
    final type = data['type']?.toString() ?? '';

    // Support replies carry a ticket id and open the chat directly.
    if (type == 'support') {
      final ticketId = int.tryParse(data['ticket_id']?.toString() ?? '');
      if (ticketId != null) {
        _navigateToSupportChat(ticketId);
        return;
      }
      Get.toNamed<void>(AppRoutes.support);
      return;
    }

    // Prefer routing by the id-bearing key in the payload: it is the most
    // reliable signal of which screen the notification is "about", regardless
    // of the exact `type` string the backend used.
    if (data.containsKey('ticket_id')) {
      final ticketId = int.tryParse(data['ticket_id']?.toString() ?? '');
      if (ticketId != null) {
        _navigateToSupportChat(ticketId);
        return;
      }
    }
    if (data.containsKey('leave_id')) {
      Get.toNamed<void>(AppRoutes.leaveManage);
      return;
    }
    if (data.containsKey('break_id')) {
      Get.toNamed<void>(AppRoutes.breakManage);
      return;
    }
    if (data.containsKey('loan_id')) {
      Get.toNamed<void>(AppRoutes.loans);
      return;
    }
    if (data.containsKey('asset_id')) {
      Get.toNamed<void>(AppRoutes.assets);
      return;
    }
    // The submissions screen is scoped to one document *type*, so it can only
    // be opened when the payload carries required_document_id. Without it we
    // fall back to the document-types list rather than opening a screen that
    // would immediately fail its request.
    if (data.containsKey('required_document_id') ||
        data.containsKey('employee_document_id')) {
      _navigateToDocumentSubmissions(data);
      return;
    }
    if (data.containsKey('payroll_id')) {
      Get.toNamed<void>(AppRoutes.reportPayroll);
      return;
    }

    switch (type) {
      case 'leave':
      case 'annual':
      case 'sick':
      case 'personal':
      case 'unpaid':
        Get.toNamed<void>(AppRoutes.leaveManage);
        break;
      case 'break':
      case 'break_approved':
      case 'break_rejected':
        Get.toNamed<void>(AppRoutes.breakManage);
        break;
      case 'loan':
      case 'advance':
        Get.toNamed<void>(AppRoutes.loans);
        break;
      case 'asset':
        Get.toNamed<void>(AppRoutes.assets);
        break;
      case 'approval':
      case 'document':
      case 'document_approved':
      case 'document_rejected':
      case 'document_removed':
        _navigateToDocumentSubmissions(data);
        break;
      case 'payroll':
      case 'payroll_approved':
      case 'payroll_paid':
      case 'bonus_added':
      case 'deduction_added':
        Get.toNamed<void>(AppRoutes.reportPayroll);
        break;
      default:
        Get.toNamed<void>(AppRoutes.notifications);
        break;
    }
  }

  /// Opens the submissions screen for the document type the notification is
  /// about. Older payloads carry no required_document_id, so those land on the
  /// document-types list instead of a screen that cannot load.
  static void _navigateToDocumentSubmissions(Map<String, dynamic> data) {
    final requiredId =
        int.tryParse(data['required_document_id']?.toString() ?? '') ?? 0;
    if (requiredId <= 0) {
      Get.toNamed<void>(AppRoutes.requiredDocuments);
      return;
    }
    Get.toNamed<void>(
      AppRoutes.requiredDocumentSubmissions,
      arguments: {
        'required_document_id': requiredId,
        'document_name': data['document_name']?.toString() ?? '',
      },
    );
  }

  static void _navigateToSupportChat(int ticketId) {
    Get.toNamed<void>(
      AppRoutes.supportChat,
      arguments: {'ticket_id': ticketId},
    );
  }
}
