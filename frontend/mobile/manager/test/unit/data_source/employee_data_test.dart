import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/crud.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/employee_data/employee_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late EmployeeData employeeData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    employeeData = EmployeeData();
  });

  tearDown(() => teardownGetX());

  group('EmployeeData', () {
    test('getEmployees ينادي getData مع endpoint الصحيح', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await employeeData.getEmployees();

      verify(() => mockCrud.getData(
            any(that: contains('list.php')),
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

    test('getEmployees مع branchId و search', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await employeeData.getEmployees(branchId: 1, search: 'أحمد');

      verify(() => mockCrud.getData(
            any(that: contains('list.php')),
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

    test('getEmployee ينادي getData مع id', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await employeeData.getEmployee(5);

      verify(() => mockCrud.getData(any(that: contains('get_profile.php')))).called(1);
    });

    test('createEmployee ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await employeeData.createEmployee({'name': 'أحمد'});

      verify(() => mockCrud.postData(
            any(that: contains('create.php')),
            {'name': 'أحمد'},
          )).called(1);
    });

    test('updateEmployee يضيف employee_id', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await employeeData.updateEmployee(5, {'name': 'أحمد'});

      verify(() => mockCrud.postData(
            any(that: contains('update.php')),
            {'name': 'أحمد', 'employee_id': 5},
          )).called(1);
    });

    test('deleteEmployee ينادي postData مع id', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await employeeData.deleteEmployee(5);

      verify(() => mockCrud.postData(
            any(that: contains('delete.php')),
            {'id': 5},
          )).called(1);
    });
  });
}
