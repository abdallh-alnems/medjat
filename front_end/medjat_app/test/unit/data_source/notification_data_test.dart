import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medjat_app/core/class/crud.dart';
import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/core/constant/id/app_links.dart';
import 'package:medjat_app/data/data_source/remote/notification_data/notification_data.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockCRUD mockCrud;
  late NotificationData notificationData;

  setUp(() {
    setupGetTestBindings();
    setupDotenvForTest();
    registerFallbacks();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    notificationData = NotificationData();
  });

  tearDown(() {
    Get.reset();
  });

  group('NotificationData', () {
    test('list sends default pagination params', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {'notifications': [], 'unread_count': 0},
              });

      final result = await notificationData.list();

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.getData(
            AppLinks.notifications,
            queryParameters: {'limit': 50, 'offset': 0},
          )).called(1);
    });

    test('list with unreadOnly adds unread_only param', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {'notifications': [], 'unread_count': 0},
              });

      final result = await notificationData.list(unreadOnly: true);

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.getData(
            AppLinks.notifications,
            queryParameters: {'limit': 50, 'offset': 0, 'unread_only': 'true'},
          )).called(1);
    });

    test('list with custom pagination', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {'notifications': [], 'unread_count': 0},
              });

      await notificationData.list(limit: 10, offset: 20);

      verify(() => mockCrud.getData(
            AppLinks.notifications,
            queryParameters: {'limit': 10, 'offset': 20},
          )).called(1);
    });

    test('markRead sends correct notification id', () async {
      when(() => mockCrud.postData(any(), any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
          });

      final result = await notificationData.markRead(42);

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.postData(
            AppLinks.notificationRead(42),
            {'id': 42},
          )).called(1);
    });

    test('getPrefs fetches notification preferences', () async {
      when(() => mockCrud.getData(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'prefs': {'late_absence': true, 'payroll_events': false},
            },
          });

      final result = await notificationData.getPrefs();

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.getData(AppLinks.notificationPrefs)).called(1);
    });

    test('updatePrefs sends preferences map', () async {
      when(() => mockCrud.postData(any(), any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
          });

      final prefs = {'late_absence': true, 'document_expiry': false};
      final result = await notificationData.updatePrefs(prefs);

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.postData(
            AppLinks.notificationPrefs,
            {'prefs': prefs},
          )).called(1);
    });
  });
}
