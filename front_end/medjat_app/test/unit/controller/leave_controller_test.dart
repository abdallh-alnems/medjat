import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/data/data_source/remote/leave_data/leave_data.dart';
import 'package:medjat_app/logic/controller/leave/leave_controller.dart';

import '../../helpers/test_helpers.dart';

class MockLeaveData extends Mock implements LeaveData {}

Widget _testApp() => GetMaterialApp(home: const SizedBox());

void main() {
  late MockLeaveData mockLeaveData;

  setUp(() {
    setupGetTestBindings();
    registerFallbacks();
    mockLeaveData = MockLeaveData();
    Get.put<LeaveData>(mockLeaveData);
  });

  tearDown(() {
    Get.reset();
  });

  group('LeaveController', () {
    test('loadBalance sets success and balance on success', () async {
      when(() => mockLeaveData.getBalance()).thenAnswer((_) async =>
          <String, dynamic>{
            'status': StatusRequest.success,
            'data': <String, dynamic>{'annual': 15, 'sick': 10},
          });

      final controller = Get.put<LeaveController>(LeaveController());

      await untilCalled(() => mockLeaveData.getBalance());

      expect(controller.status, StatusRequest.success);
      expect(controller.balance, isNotNull);
      expect(controller.balance!['annual'], 15);
    });

    test('loadBalance sets failure on error', () async {
      when(() => mockLeaveData.getBalance()).thenAnswer((_) async =>
          <String, dynamic>{'status': StatusRequest.failure});

      final controller = Get.put<LeaveController>(LeaveController());

      await untilCalled(() => mockLeaveData.getBalance());

      expect(controller.status, StatusRequest.failure);
      expect(controller.balance, isNull);
    });

    testWidgets('applyLeave returns true on success', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      when(() => mockLeaveData.getBalance()).thenAnswer((_) async =>
          <String, dynamic>{
            'status': StatusRequest.success,
            'data': <String, dynamic>{},
          });
      when(() => mockLeaveData.apply(
            date: any(named: 'date'),
            type: any(named: 'type'),
            reason: any(named: 'reason'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => <String, dynamic>{
            'status': StatusRequest.success,
            'data': <String, dynamic>{'id': 10},
          });

      final controller = Get.put<LeaveController>(LeaveController());
      await untilCalled(() => mockLeaveData.getBalance());
      await tester.pumpAndSettle();

      final result = await controller.applyLeave(
        date: '2026-05-25',
        type: 'annual',
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(result, true);
      expect(controller.applyStatus, StatusRequest.success);
    });

    testWidgets('applyLeave returns false on failure', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      when(() => mockLeaveData.getBalance()).thenAnswer((_) async =>
          <String, dynamic>{
            'status': StatusRequest.success,
            'data': <String, dynamic>{},
          });
      when(() => mockLeaveData.apply(
            date: any(named: 'date'),
            type: any(named: 'type'),
            reason: any(named: 'reason'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => <String, dynamic>{
            'status': StatusRequest.failure,
            'statusCode': 409,
            'message': 'يوجد تداخل',
          });

      final controller = Get.put<LeaveController>(LeaveController());
      await untilCalled(() => mockLeaveData.getBalance());
      await tester.pumpAndSettle();

      final result = await controller.applyLeave(
        date: '2026-05-25',
        type: 'annual',
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(result, false);
      expect(controller.applyStatus, StatusRequest.failure);
    });

    testWidgets('applyLeave includes optional fields', (tester) async {
      await tester.pumpWidget(_testApp());
      await tester.pumpAndSettle();

      when(() => mockLeaveData.getBalance()).thenAnswer((_) async =>
          <String, dynamic>{
            'status': StatusRequest.success,
            'data': <String, dynamic>{},
          });
      when(() => mockLeaveData.apply(
            date: any(named: 'date'),
            type: any(named: 'type'),
            reason: any(named: 'reason'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          )).thenAnswer((_) async => <String, dynamic>{
            'status': StatusRequest.success,
            'data': <String, dynamic>{'id': 11},
          });

      final controller = Get.put<LeaveController>(LeaveController());
      await untilCalled(() => mockLeaveData.getBalance());
      await tester.pumpAndSettle();

      final result = await controller.applyLeave(
        date: '2026-05-25',
        type: 'sick',
        reason: 'إجازة مرضية',
        startDate: '2026-05-25',
        endDate: '2026-05-26',
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(result, true);
    });
  });
}
