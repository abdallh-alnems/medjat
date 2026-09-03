import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/crud.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/payroll_data/payroll_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late PayrollData payrollData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    payrollData = PayrollData();
  });

  tearDown(() => teardownGetX());

  group('PayrollData', () {
    test('getPayrolls ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await payrollData.getPayrolls();

      verify(() => mockCrud.getData(
            any(that: contains('list_slips.php')),
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

    test('getPayrollMonth ينادي getData مع month', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await payrollData.getPayrollMonth(6, 2024);

      verify(() => mockCrud.getData(
            any(that: contains('list_slips.php')),
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

    test('approvePayroll ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await payrollData.approvePayroll(1);

      verify(() => mockCrud.postData(
            any(that: contains('approve.php')),
            {},
          )).called(1);
    });

    test('addManualDeduction ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await payrollData.addManualDeduction(
        employeeId: 5,
        amount: 100,
        reason: 'خصم تأخير',
      );

      verify(() => mockCrud.postData(
            any(that: contains('add_manual.php')),
            {'employee_id': 5, 'amount': 100, 'reason': 'خصم تأخير'},
          )).called(1);
    });

    test('addManualBonus ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await payrollData.addManualBonus(
        employeeId: 5,
        amount: 200,
        reason: 'مكافأة',
      );

      verify(() => mockCrud.postData(
            any(that: contains('add_manual.php')),
            {'employee_id': 5, 'amount': 200, 'reason': 'مكافأة'},
          )).called(1);
    });
  });
}
