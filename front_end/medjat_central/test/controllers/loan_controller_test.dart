import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/loan_data/loan_data.dart';
import 'package:medjat_central/logic/controller/loan/loan_controller.dart';
import '../helpers/test_helpers.dart';

class MockLoanData extends Mock implements LoanData {}

void main() {
  late MockLoanData mockData;
  late LoanController controller;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockLoanData();
    Get.put<LoanData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('LoanController — تحميل البيانات', () {
    test('نجاح الجلب يملأ القائمة', () async {
      when(() => mockData.getLoans(status: any(named: 'status'))).thenAnswer(
          (_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{
                  'items': [
                    {'id': 1, 'employee_id': 5, 'type': 'loan', 'total_amount': 5000, 'status': 'active'},
                  ],
                },
              });

      controller = LoanController();
      await controller.loadLoans();

      expect(controller.status, StatusRequest.success);
      expect(controller.loans.length, 1);
      expect(controller.loans.first.totalAmount, 5000.0);
    });

    test('فشل الجلب', () async {
      when(() => mockData.getLoans(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      controller = LoanController();
      await controller.loadLoans();

      expect(controller.status, StatusRequest.failure);
      expect(controller.loans, isEmpty);
    });

    test('حالة offline', () async {
      when(() => mockData.getLoans(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.offline});

      controller = LoanController();
      await controller.loadLoans();

      expect(controller.status, StatusRequest.offline);
    });

    test('data كـ List مباشر', () async {
      when(() => mockData.getLoans(status: any(named: 'status'))).thenAnswer(
          (_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': [
                  {'id': 1, 'employee_id': 5, 'type': 'advance', 'total_amount': 2000, 'status': 'pending'},
                ],
              });

      controller = LoanController();
      await controller.loadLoans();

      expect(controller.loans.length, 1);
      expect(controller.loans.first.type, 'advance');
    });

    test('filterByStatus يعيد التحميل', () async {
      when(() => mockData.getLoans(status: any(named: 'status'))).thenAnswer(
          (_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': []},
              });

      controller = LoanController();
      await controller.loadLoans();

      controller.filterByStatus('active');

      verify(() => mockData.getLoans(status: any(named: 'status'))).called(2);
    });

    test('data فارغة', () async {
      when(() => mockData.getLoans(status: any(named: 'status'))).thenAnswer(
          (_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': null,
              });

      controller = LoanController();
      await controller.loadLoans();

      expect(controller.status, StatusRequest.success);
      expect(controller.loans, isEmpty);
    });
  });
}
