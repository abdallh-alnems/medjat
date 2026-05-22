import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/payroll_data/payroll_data.dart';
import 'package:medjat_central/logic/controller/payroll/payroll_controller.dart';
import '../helpers/test_helpers.dart';

class MockPayrollData extends Mock implements PayrollData {}

void main() {
  late MockPayrollData mockData;
  late PayrollController controller;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockPayrollData();
    Get.put<PayrollData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('PayrollController — تحميل البيانات', () {
    test('نجاح الجلب يملأ القائمة', () async {
      when(() => mockData.getPayrollMonth(any(), any(),
              branchId: any(named: 'branchId')))
          .thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{
                  'items': [
                    {'id': 1, 'employee_id': 5, 'month': 6, 'year': 2024, 'net_salary': 9700, 'status': 'approved'},
                  ],
                },
              });

      controller = PayrollController();
      await controller.loadPayrolls();

      expect(controller.status, StatusRequest.success);
      expect(controller.payrolls.length, 1);
      expect(controller.payrolls.first.netSalary, 9700.0);
    });

    test('فشل الجلب', () async {
      when(() => mockData.getPayrollMonth(any(), any(),
              branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      controller = PayrollController();
      await controller.loadPayrolls();

      expect(controller.status, StatusRequest.serverFailure);
      expect(controller.payrolls, isEmpty);
    });

    test('changeMonth يعيد التحميل', () async {
      when(() => mockData.getPayrollMonth(any(), any(),
              branchId: any(named: 'branchId')))
          .thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': []},
              });

      controller = PayrollController();
      await controller.loadPayrolls();

      controller.changeMonth(1, 2024);

      expect(controller.selectedMonth, 1);
      expect(controller.selectedYear, 2024);
      verify(() => mockData.getPayrollMonth(any(), any(),
              branchId: any(named: 'branchId')))
          .called(2);
    });

    test('getBankFilePreview عند النجاح', () async {
      when(() => mockData.getPayrollMonth(any(), any(),
              branchId: any(named: 'branchId')))
          .thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': []},
              });
      when(() => mockData.getBankFilePreview(any(),
              branchId: any(named: 'branchId')))
          .thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{
                  'month': '2024-06',
                  'total_employees': 10,
                  'total_amount': 100000,
                },
              });

      controller = PayrollController();
      await controller.loadPayrolls();
      final preview = await controller.getBankFilePreview();

      expect(preview, isNotNull);
      expect(preview!['total_employees'], 10);
    });

    test('getBankFilePreview عند الفشل يرجع null', () async {
      when(() => mockData.getPayrollMonth(any(), any(),
              branchId: any(named: 'branchId')))
          .thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': []},
              });
      when(() => mockData.getBankFilePreview(any(),
              branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      controller = PayrollController();
      await controller.loadPayrolls();
      final preview = await controller.getBankFilePreview();

      expect(preview, isNull);
    });

    test('hasApprovedPayrolls', () async {
      when(() => mockData.getPayrollMonth(any(), any(),
              branchId: any(named: 'branchId')))
          .thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{
                  'items': [
                    {'id': 1, 'employee_id': 5, 'month': 6, 'year': 2024, 'status': 'approved'},
                  ],
                },
              });

      controller = PayrollController();
      await controller.loadPayrolls();

      expect(controller.hasApprovedPayrolls, isTrue);
    });
  });
}
