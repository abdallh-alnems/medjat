import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/leave_data/leave_data.dart';
import 'package:medjat_central/logic/controller/leave/leave_controller.dart';
import '../helpers/test_helpers.dart';

class MockLeaveData extends Mock implements LeaveData {}

void main() {
  late MockLeaveData mockData;
  late LeaveController controller;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockLeaveData();
    Get.put<LeaveData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('LeaveController — تحميل البيانات', () {
    test('نجاح الجلب يملأ القائمة', () async {
      when(() => mockData.getLeaves(status: any(named: 'status'))).thenAnswer(
          (_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{
                  'items': [
                    {'id': 1, 'employee_id': 5, 'type': 'annual', 'start_date': '2024-06-01', 'status': 'pending'},
                  ],
                },
              });

      controller = LeaveController();
      await controller.loadLeaves();

      expect(controller.status, StatusRequest.success);
      expect(controller.leaves.length, 1);
    });

    test('فشل الجلب', () async {
      when(() => mockData.getLeaves(status: any(named: 'status')))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      controller = LeaveController();
      await controller.loadLeaves();

      expect(controller.status, StatusRequest.failure);
      expect(controller.leaves, isEmpty);
    });

    test('loadBalance عند النجاح', () async {
      when(() => mockData.getLeaves(status: any(named: 'status'))).thenAnswer(
          (_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': []},
              });
      when(() => mockData.leaveBalance(any(), year: any(named: 'year')))
          .thenAnswer((_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'remaining_days': 10, 'total_days': 21},
              });

      controller = LeaveController();
      await controller.loadLeaves();
      await controller.loadBalance(5);

      expect(controller.balanceLoading, isFalse);
      expect(controller.balanceInfo, isNotNull);
      expect(controller.balanceInfo!['remaining_days'], 10);
    });

    test('loadBalance عند الفشل يبقي balanceInfo فارغ', () async {
      when(() => mockData.getLeaves(status: any(named: 'status'))).thenAnswer(
          (_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': []},
              });
      when(() => mockData.leaveBalance(any(), year: any(named: 'year')))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      controller = LeaveController();
      await controller.loadLeaves();
      await controller.loadBalance(5);

      expect(controller.balanceLoading, isFalse);
      expect(controller.balanceInfo, isNull);
    });

    test('filterByStatus يعيد التحميل', () async {
      when(() => mockData.getLeaves(status: any(named: 'status'))).thenAnswer(
          (_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'items': []},
              });

      controller = LeaveController();
      await controller.loadLeaves();

      controller.filterByStatus('approved');

      verify(() => mockData.getLeaves(status: any(named: 'status'))).called(2);
    });
  });
}
