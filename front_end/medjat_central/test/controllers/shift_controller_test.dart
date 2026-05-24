import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/shift_data/shift_data.dart';
import 'package:medjat_central/data/model/shift_model.dart';
import 'package:medjat_central/logic/controller/shift/shift_controller.dart';
import '../helpers/test_helpers.dart';

class MockShiftData extends Mock implements ShiftData {}

void main() {
  late MockShiftData mockData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockShiftData();
    Get.put<ShiftData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('ShiftController', () {
    test('loadShifts — نجاح', () async {
      when(() => mockData.getShifts(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': [
                  {'id': 1, 'name': 'صباحي', 'start_time': '08:00', 'end_time': '16:00'},
                ],
              });

      final controller = ShiftController();
      await controller.loadShifts();

      expect(controller.status, StatusRequest.success);
      expect(controller.shifts.length, 1);
      expect(controller.shifts.first.name, 'صباحي');
    });

    test('loadShifts — فشل', () async {
      when(() => mockData.getShifts(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      final controller = ShiftController();
      await controller.loadShifts();

      expect(controller.status, StatusRequest.failure);
    });

    test('createShift — نجاح يعيد true', () async {
      when(() => mockData.createShift(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});
      when(() => mockData.getShifts(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      final controller = ShiftController();
      await controller.loadShifts();

      final result = await controller.createShift(
        name: 'مسائي',
        startTime: '16:00',
        endTime: '00:00',
      );

      expect(result, isTrue);
    });

    test('deleteShift — نجاح يعيد true', () async {
      when(() => mockData.deleteShift(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});
      when(() => mockData.getShifts(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      final controller = ShiftController();
      await controller.loadShifts();

      final result = await controller.deleteShift(5);

      expect(result, isTrue);
    });

    test('assignEmployees — نجاح يعيد عدد المخصصين', () async {
      when(() => mockData.assignEmployees(shiftId: any(named: 'shiftId'), employeeIds: any(named: 'employeeIds')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {'data': {'assigned': 3}},
              });
      when(() => mockData.getShifts(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      final controller = ShiftController();
      await controller.loadShifts();

      final count = await controller.assignEmployees(1, [10, 20, 30]);

      expect(count, 3);
    });

    test('assignEmployees — فشل يعيد 0', () async {
      when(() => mockData.assignEmployees(shiftId: any(named: 'shiftId'), employeeIds: any(named: 'employeeIds')))
          .thenAnswer((_) async => {'status': StatusRequest.failure});
      when(() => mockData.getShifts(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      final controller = ShiftController();
      await controller.loadShifts();

      final count = await controller.assignEmployees(1, [10, 20]);

      expect(count, 0);
    });
  });
}
