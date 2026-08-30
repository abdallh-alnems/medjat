import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

/// Shows real system notifications (tray + sound) when an FCM message arrives
/// while the app is in the foreground. In the background/terminated state the
/// OS displays the message's `notification` payload itself, routed to the same
/// high-importance channel declared in the AndroidManifest.
class LocalNotificationsService {
  LocalNotificationsService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'high_importance_channel';

  /// تُبنى عند الطلب لتأخذ اسماً ووصفاً مترجمَين حسب لغة التطبيق الحالية.
  static AndroidNotificationChannel get _channel => AndroidNotificationChannel(
        _channelId,
        'notif_channel_name'.tr,
        description: 'notif_channel_desc'.tr,
        importance: Importance.max,
      );

  /// Called when the user taps a notification, with its data payload.
  static void Function(Map<String, dynamic> data)? onTap;

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onResponse,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.requestNotificationsPermission();

    _ready = true;
  }

  static Future<void> show(
      String? title, String? body, Map<String, dynamic> data) async {
    if (!_ready) return;
    try {
      await _showInternal(title, body, data);
    } catch (_) {
      // Plugin unavailable (e.g. stale build) — fail quietly.
    }
  }

  static Future<void> _showInternal(
      String? title, String? body, Map<String, dynamic> data) async {
    final channel = _channel;
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      payload: jsonEncode(data),
    );
  }

  static void _onResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        onTap?.call(decoded.map((k, v) => MapEntry(k.toString(), v)));
      }
    } catch (_) {}
  }
}
