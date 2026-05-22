import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/expense_data/expense_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late ExpenseData expenseData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    expenseData = ExpenseData();
  });

  tearDown(() => teardownGetX());

  group('ExpenseData', () {
    test('getExpenses بدون فلتر', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await expenseData.getExpenses();

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getExpenses مع status filter', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await expenseData.getExpenses(status: 'pending');

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('createExpense ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await expenseData.createExpense({'amount': 500});

      verify(() => mockCrud.postData(any(), {'amount': 500})).called(1);
    });

    test('approveExpense ينادي postData مع id', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await expenseData.approveExpense(3);

      verify(() => mockCrud.postData(any(), {'id': 3})).called(1);
    });

    test('rejectExpense مع reason', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await expenseData.rejectExpense(3, reason: 'غير مكتمل');

      verify(() => mockCrud.postData(any(), any())).called(1);
    });

    test('reimburseExpense ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await expenseData.reimburseExpense(3);

      verify(() => mockCrud.postData(any(), {'id': 3})).called(1);
    });
  });
}
