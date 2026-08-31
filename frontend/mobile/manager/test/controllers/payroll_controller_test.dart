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
      when(() => mockData.getPayrollLive(any(), any(),
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
      when(() => mockData.getPayrollLive(any(), any(),
              branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      controller = PayrollController();
      await controller.loadPayrolls();

      expect(controller.status, StatusRequest.serverFailure);
      expect(controller.payrolls, isEmpty);
    });

    test('changeMonth يعيد التحميل', () async {
      when(() => mockData.getPayrollLive(any(), any(),
              branchId: any(named: 'branchId')))
          .thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': <Map<String, dynamic>>[]},
              });

      controller = PayrollController();
      await controller.loadPayrolls();

      // The first successful load anchors the picker on the latest *completed*
      // cycle, and that re-fetch is a second call. Counting from zero here
      // keeps this test about the reload `changeMonth` itself triggers.
      clearInteractions(mockData);

      controller.changeMonth(1, 2024);

      expect(controller.selectedMonth, 1);
      expect(controller.selectedYear, 2024);
      verify(() => mockData.getPayrollLive(any(), any(),
              branchId: any(named: 'branchId')))
          .called(1);
    });

  });
}
