import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/crud.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/notification_data/notification_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late NotificationData data;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    data = NotificationData();
  });

  tearDown(() => teardownGetX());

  group('NotificationData', () {
    test('getNotifications ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getNotifications();

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('markAsRead ينادي postData مع id', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.markAsRead(5);

      verify(() => mockCrud.postData(any(), {'id': 5})).called(1);
    });

    test('getPrefs ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getPrefs();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('savePrefs ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.savePrefs({'push': true});

      verify(() => mockCrud.postData(any(), {'prefs': {'push': true}})).called(1);
    });
  });
}
