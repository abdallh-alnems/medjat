import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medjat_app/core/class/crud.dart';
import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/data/data_source/remote/payroll_data/payroll_data.dart';
import 'package:medjat_app/logic/controller/payroll/payroll_controller.dart';

import '../../helpers/test_helpers.dart';

class MockPayrollData extends Mock implements PayrollData {}

void main() {
  late MockPayrollData mockPayrollData;

  setUp(() {
    setupGetTestBindings();
    registerFallbacks();
    mockPayrollData = MockPayrollData();
    Get.put<PayrollData>(mockPayrollData);
    Get.put<CRUD>(MockCRUD());
  });

  tearDown(() {
    Get.reset();
  });

  group('PayrollController', () {
    test('loadSlip sets success and slipData', () async {
      when(() => mockPayrollData.getSlip(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'month': '2026-05',
              'net_salary': 8000.0,
              'deductions': 500.0,
            },
          });

      final controller = Get.put<PayrollController>(PayrollController());

      await untilCalled(() => mockPayrollData.getSlip(any()));

      expect(controller.status, StatusRequest.success);
      expect(controller.slipData, isNotNull);
      expect(controller.slipData!['net_salary'], 8000.0);
    });

    test('loadSlip sets offline status', () async {
      when(() => mockPayrollData.getSlip(any())).thenAnswer((_) async => {
            'status': StatusRequest.offline,
          });

      final controller = Get.put<PayrollController>(PayrollController());

      await untilCalled(() => mockPayrollData.getSlip(any()));

      expect(controller.status, StatusRequest.offline);
    });

    test('loadSlip sets failure on error', () async {
      when(() => mockPayrollData.getSlip(any())).thenAnswer((_) async => {
            'status': StatusRequest.failure,
          });

      final controller = Get.put<PayrollController>(PayrollController());

      await untilCalled(() => mockPayrollData.getSlip(any()));

      expect(controller.status, StatusRequest.failure);
    });

    test('changeMonth updates selectedMonth and reloads', () async {
      when(() => mockPayrollData.getSlip(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'month': '2026-04'},
          });

      final controller = Get.put<PayrollController>(PayrollController());
      await untilCalled(() => mockPayrollData.getSlip(any()));

      when(() => mockPayrollData.getSlip('2026-04')).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'month': '2026-04'},
          });

      controller.changeMonth('2026-04');

      await untilCalled(() => mockPayrollData.getSlip('2026-04'));

      expect(controller.selectedMonth, '2026-04');
      verify(() => mockPayrollData.getSlip('2026-04')).called(1);
    });
  });
}
