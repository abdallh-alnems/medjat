import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/role_data/role_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late RoleData roleData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    roleData = RoleData();
  });

  tearDown(() => teardownGetX());

  group('RoleData', () {
    test('getRoles ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await roleData.getRoles();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('createRole ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await roleData.createRole({'name': 'مشرف'});

      verify(() => mockCrud.postData(any(), {'name': 'مشرف'})).called(1);
    });

    test('updateRole ينادي putData', () async {
      when(() => mockCrud.putData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await roleData.updateRole(3, {'name': 'محدث'});

      verify(() => mockCrud.putData(any(), {'name': 'محدث'})).called(1);
    });

    test('deleteRole ينادي deleteData', () async {
      when(() => mockCrud.deleteData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await roleData.deleteRole(5);

      verify(() => mockCrud.deleteData(any())).called(1);
    });
  });
}
