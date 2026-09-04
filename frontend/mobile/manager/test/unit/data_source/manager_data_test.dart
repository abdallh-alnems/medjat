import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/crud.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/manager_data/manager_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late ManagerData managerData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    managerData = ManagerData();
  });

  tearDown(() => teardownGetX());

  group('ManagerData', () {
    test('createInvitation ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await managerData.createInvitation({'email': 'test@test.com'});

      verify(() => mockCrud.postData(any(), {'email': 'test@test.com'})).called(1);
    });

    test('getInvitations ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await managerData.getInvitations();

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('cancelInvitation ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await managerData.cancelInvitation(5);

      verify(() => mockCrud.postData(any(), {})).called(1);
    });

    test('getAdmins ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await managerData.getAdmins();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('getAdminPermissions ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await managerData.getAdminPermissions(3);

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('updateAdminPermissions ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await managerData.updateAdminPermissions(
        adminId: 3,
        permissions: ['view', 'edit'],
      );

      verify(() => mockCrud.postData(any(), {
        'admin_id': 3,
        'permissions': ['view', 'edit'],
      })).called(1);
    });

    test('resetAdminPermissions ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await managerData.resetAdminPermissions(3);

      verify(() => mockCrud.postData(any(), {'admin_id': 3})).called(1);
    });
  });
}
