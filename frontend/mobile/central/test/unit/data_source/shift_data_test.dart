import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/shift_data/shift_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late ShiftData shiftData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    shiftData = ShiftData();
  });

  tearDown(() => teardownGetX());

  group('ShiftData', () {
    test('getShifts بدون branchId', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await shiftData.getShifts();

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getShifts مع branchId', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await shiftData.getShifts(branchId: 3);

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('createShift ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await shiftData.createShift({'name': 'صباحي'});

      verify(() => mockCrud.postData(any(), {'name': 'صباحي'})).called(1);
    });

    test('updateShift ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await shiftData.updateShift(5, {'name': 'مسائي'});

      verify(() => mockCrud.postData(any(), {'name': 'مسائي'})).called(1);
    });

    test('deleteShift ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await shiftData.deleteShift(5);

      verify(() => mockCrud.postData(any(), {})).called(1);
    });

    test('assignEmployees ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await shiftData.assignEmployees(shiftId: 1, employeeIds: [10, 20]);

      verify(() => mockCrud.postData(any(), {
        'shift_id': 1,
        'employee_ids': [10, 20],
      })).called(1);
    });
  });
}
