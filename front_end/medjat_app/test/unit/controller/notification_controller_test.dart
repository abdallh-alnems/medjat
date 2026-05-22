import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/data/data_source/remote/notification_data/notification_data.dart';
import 'package:medjat_app/logic/controller/notification/notification_controller.dart';

import '../../helpers/test_helpers.dart';

class MockNotificationData extends Mock implements NotificationData {}

void main() {
  late MockNotificationData mockNotificationData;

  setUp(() {
    setupGetTestBindings();
    registerFallbacks();
    mockNotificationData = MockNotificationData();
    Get.put<NotificationData>(mockNotificationData);
  });

  tearDown(() {
    Get.reset();
  });

  group('NotificationController', () {
    test('loadNotifications populates list and unreadCount', () async {
      when(() => mockNotificationData.list()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'notifications': [
                {'id': 1, 'title': 'تنبيه', 'read_at': null},
                {'id': 2, 'title': 'رسالة', 'read_at': '2026-05-21T10:00:00'},
              ],
              'unread_count': 1,
            },
          });
      when(() => mockNotificationData.getPrefs()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'prefs': {'late_absence': true}},
          });

      final controller =
          Get.put<NotificationController>(NotificationController());

      await untilCalled(() => mockNotificationData.list());

      expect(controller.status, StatusRequest.success);
      expect(controller.notifications.length, 2);
      expect(controller.unreadCount, 1);
    });

    test('loadNotifications handles empty data', () async {
      when(() => mockNotificationData.list()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': null,
          });
      when(() => mockNotificationData.getPrefs()).thenAnswer((_) async => {
            'status': StatusRequest.failure,
          });

      final controller =
          Get.put<NotificationController>(NotificationController());

      await untilCalled(() => mockNotificationData.list());

      expect(controller.status, StatusRequest.success);
      expect(controller.notifications, isEmpty);
      expect(controller.unreadCount, 0);
    });

    test('loadNotifications sets failure on error', () async {
      when(() => mockNotificationData.list()).thenAnswer((_) async => {
            'status': StatusRequest.failure,
          });
      when(() => mockNotificationData.getPrefs()).thenAnswer((_) async => {
            'status': StatusRequest.failure,
          });

      final controller =
          Get.put<NotificationController>(NotificationController());

      await untilCalled(() => mockNotificationData.list());

      expect(controller.status, StatusRequest.failure);
    });

    test('markAsRead updates notification and decrements unreadCount',
        () async {
      when(() => mockNotificationData.list()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'notifications': [
                {'id': 1, 'title': 'تنبيه', 'read_at': null},
              ],
              'unread_count': 1,
            },
          });
      when(() => mockNotificationData.getPrefs()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'prefs': {'late_absence': true}},
          });
      when(() => mockNotificationData.markRead(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success});

      final controller =
          Get.put<NotificationController>(NotificationController());

      await untilCalled(() => mockNotificationData.list());

      expect(controller.unreadCount, 1);

      await controller.markAsRead(1);

      expect(controller.notifications[0]['read_at'], isNotNull);
      expect(controller.unreadCount, 0);
    });

    test('loadPrefs updates preferences map', () async {
      when(() => mockNotificationData.list()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'notifications': [], 'unread_count': 0},
          });
      when(() => mockNotificationData.getPrefs()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'prefs': {
                'late_absence': false,
                'payroll_events': true,
              },
            },
          });

      final controller =
          Get.put<NotificationController>(NotificationController());

      await untilCalled(() => mockNotificationData.getPrefs());

      expect(controller.prefs['late_absence'], false);
      expect(controller.prefs['payroll_events'], true);
    });

    test('updatePref calls API with updated prefs', () async {
      when(() => mockNotificationData.list()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'notifications': [], 'unread_count': 0},
          });
      when(() => mockNotificationData.getPrefs()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'prefs': {'late_absence': true}},
          });
      when(() => mockNotificationData.updatePrefs(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success});

      final controller =
          Get.put<NotificationController>(NotificationController());

      await untilCalled(() => mockNotificationData.list());

      await controller.updatePref('late_absence', false);

      expect(controller.prefs['late_absence'], false);
      verify(() => mockNotificationData.updatePrefs(any())).called(1);
    });
  });
}
