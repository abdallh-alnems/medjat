import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/expense_data/expense_data.dart';
import 'package:medjat_central/data/model/expense_claim_model.dart';
import 'package:medjat_central/logic/controller/expense/expense_controller.dart';
import '../helpers/test_helpers.dart';

class MockExpenseData extends Mock implements ExpenseData {}

void main() {
  late MockExpenseData mockData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockExpenseData();
    Get.put<ExpenseData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('ExpenseController', () {
    test('loadExpenses — نجاح', () async {
      when(() => mockData.getExpenses(status: any(named: 'status')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': [
                  {'id': 1, 'employee_id': 5, 'amount': 500.0, 'category': 'travel', 'status': 'pending', 'expense_date': '2025-01-15'},
                ],
              });

      final controller = ExpenseController();
      await controller.loadExpenses();

      expect(controller.status, StatusRequest.success);
      expect(controller.expenses.length, 1);
    });

    test('loadExpenses — فشل', () async {
      when(() => mockData.getExpenses(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      final controller = ExpenseController();
      await controller.loadExpenses();

      expect(controller.status, StatusRequest.serverFailure);
    });

    test('filterByStatus يحدث statusFilter', () async {
      when(() => mockData.getExpenses(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      final controller = ExpenseController();
      await controller.loadExpenses();

      controller.filterByStatus('approved');

      expect(controller.statusFilter, 'approved');
    });

    test('createExpense — نجاح يعيد true', () async {
      when(() => mockData.createExpense(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});
      when(() => mockData.getExpenses(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      final controller = ExpenseController();
      await controller.loadExpenses();

      final result = await controller.createExpense(
        employeeId: 1,
        category: 'travel',
        amount: 100.0,
        expenseDate: DateTime(2025, 6, 1),
      );

      expect(result, isTrue);
    });

    test('createExpense — فشل يعيد false', () async {
      when(() => mockData.createExpense(any()))
          .thenAnswer((_) async => {'status': StatusRequest.failure});
      when(() => mockData.getExpenses(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      final controller = ExpenseController();
      await controller.loadExpenses();

      final result = await controller.createExpense(
        employeeId: 1,
        category: 'travel',
        amount: 100.0,
        expenseDate: DateTime(2025, 6, 1),
      );

      expect(result, isFalse);
    });
  });
}
