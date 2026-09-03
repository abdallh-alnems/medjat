import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:permedjat_app/core/class/crud.dart';
import 'package:permedjat_app/core/class/status_request.dart';
import 'package:permedjat_app/core/constant/id/app_links.dart';
import 'package:permedjat_app/data/data_source/remote/leave_data/leave_data.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockCRUD mockCrud;
  late LeaveData leaveData;

  setUp(() {
    setupGetTestBindings();
    setupDotenvForTest();
    registerFallbacks();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    leaveData = LeaveData();
  });

  tearDown(() {
    Get.reset();
  });

  group('LeaveData', () {
    test('apply sends required fields only', () async {
      when(() => mockCrud.postData(any(), any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'id': 10},
          });

      final result = await leaveData.apply(
        date: '2026-05-25',
        type: 'sick',
      );

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.postData(AppLinks.leaveApply, {
            'date': '2026-05-25',
            'type': 'sick',
          })).called(1);
    });

    test('apply includes optional fields when provided', () async {
      when(() => mockCrud.postData(any(), any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'id': 11},
          });

      final result = await leaveData.apply(
        date: '2026-05-25',
        type: 'annual',
        reason: 'إجازة سنوية',
        startDate: '2026-05-25',
        endDate: '2026-05-28',
      );

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.postData(AppLinks.leaveApply, {
            'date': '2026-05-25',
            'type': 'annual',
            'reason': 'إجازة سنوية',
            'start_date': '2026-05-25',
            'end_date': '2026-05-28',
          })).called(1);
    });

    test('getBalance without year sends empty params', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {'balance': 15},
              });

      final result = await leaveData.getBalance();

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.getData(
            AppLinks.leaveBalance,
            queryParameters: {},
          )).called(1);
    });

    test('getBalance with year sends year parameter', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {'balance': 15},
              });

      final result = await leaveData.getBalance(year: 2026);

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.getData(
            AppLinks.leaveBalance,
            queryParameters: {'year': '2026'},
          )).called(1);
    });

    test('apply returns conflict on overlap', () async {
      when(() => mockCrud.postData(any(), any())).thenAnswer((_) async => {
            'status': StatusRequest.failure,
            'statusCode': 409,
            'message': 'يوجد تداخل مع إجازة قائمة',
          });

      final result = await leaveData.apply(
        date: '2026-05-25',
        type: 'annual',
      );

      expect(result['status'], StatusRequest.failure);
      expect(result['statusCode'], 409);
    });
  });
}
