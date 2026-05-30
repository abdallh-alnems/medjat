import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/leave_data/leave_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late LeaveData leaveData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    leaveData = LeaveData();
  });

  tearDown(() => teardownGetX());

  group('LeaveData', () {
    test('getLeaves ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await leaveData.getLeaves();

      verify(() => mockCrud.getData(
            any(that: contains('list.php')),
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

    test('approveLeave ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await leaveData.approveLeave(1);

      verify(() => mockCrud.postData(
            any(that: contains('approve.php')),
            {},
          )).called(1);
    });

    test('rejectLeave ينادي postData مع reason', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await leaveData.rejectLeave(1, reason: 'غير مبرر');

      verify(() => mockCrud.postData(
            any(that: contains('reject.php')),
            {'rejection_reason': 'غير مبرر'},
          )).called(1);
    });

    test('rejectLeave بدون reason', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await leaveData.rejectLeave(1);

      verify(() => mockCrud.postData(
            any(that: contains('reject.php')),
            {},
          )).called(1);
    });

    test('createLeave ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await leaveData.createLeave({'employee_id': 5, 'type': 'annual'});

      verify(() => mockCrud.postData(
            any(that: contains('create.php')),
            {'employee_id': 5, 'type': 'annual'},
          )).called(1);
    });

    test('createRecurringLeave ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await leaveData.createRecurringLeave({'day_of_week': 'friday'});

      verify(() => mockCrud.postData(
            any(that: contains('create_recurring.php')),
            {'day_of_week': 'friday'},
          )).called(1);
    });

    test('leaveBalance ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await leaveData.leaveBalance(5);

      verify(() => mockCrud.getData(
            any(that: contains('get_balance.php')),
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

  });
}
