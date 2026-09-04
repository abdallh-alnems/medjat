import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:permedjat_app/core/class/crud.dart';
import 'package:permedjat_app/core/class/status_request.dart';
import 'package:permedjat_app/core/constant/id/app_links.dart';
import 'package:permedjat_app/data/data_source/remote/payroll_data/payroll_data.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockCRUD mockCrud;
  late PayrollData payrollData;

  setUp(() {
    setupGetTestBindings();
    setupDotenvForTest();
    registerFallbacks();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    payrollData = PayrollData();
  });

  tearDown(() {
    Get.reset();
  });

  group('PayrollData', () {
    test('getSlip sends correct month', () async {
      when(() => mockCrud.getData(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'month': '2026-05', 'net_salary': 5000},
          });

      final result = await payrollData.getSlip('2026-05');

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.getData(AppLinks.payrollSlipMonth('2026-05')))
          .called(1);
    });

    test('getSlipPdf fetches bytes', () async {
      when(() => mockCrud.getBytes(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'bytes': [1, 2, 3, 4],
          });

      final result = await payrollData.getSlipPdf('2026-05');

      expect(result['status'], StatusRequest.success);
      expect(result['bytes'], isNotNull);
      verify(() => mockCrud.getBytes(AppLinks.payrollPdf('2026-05')))
          .called(1);
    });

    test('getSlip returns offline status', () async {
      when(() => mockCrud.getData(any())).thenAnswer((_) async => {
            'status': StatusRequest.offline,
          });

      final result = await payrollData.getSlip('2026-05');

      expect(result['status'], StatusRequest.offline);
    });

    test('getSlipPdf returns failure on error', () async {
      when(() => mockCrud.getBytes(any())).thenAnswer((_) async => {
            'status': StatusRequest.failure,
            'statusCode': 404,
          });

      final result = await payrollData.getSlipPdf('2026-05');

      expect(result['status'], StatusRequest.failure);
    });
  });
}
