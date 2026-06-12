import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../data/data_source/remote/device_data/device_data.dart';
import '../../../core/constant/routes/app_routes.dart';

class PushNotificationService extends GetxService {
  final DeviceData _deviceData = Get.find<DeviceData>();

  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push notification permission denied');
      return;
    }

    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    messaging.onTokenRefresh.listen((newToken) {
      _registerToken(newToken);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
  }

  void _handleMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'support' && data['ticket_id'] != null) {
      final ticketId = int.tryParse(data['ticket_id'].toString());
      if (ticketId != null) {
        Get.toNamed(
          AppRoutes.supportThread,
          arguments: {'ticket_id': ticketId},
        );
      }
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      String platform = 'android';
      if (Platform.isIOS) platform = 'ios';

      final packageInfo = await PackageInfo.fromPlatform();

      await _deviceData.register(
        fcmToken: token,
        platform: platform,
        appVersion: packageInfo.version,
      );
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }
}
