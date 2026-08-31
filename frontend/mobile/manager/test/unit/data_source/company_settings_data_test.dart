import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/company_settings_data/company_settings_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late CompanySettingsData data;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    data = CompanySettingsData();
  });

  tearDown(() => teardownGetX());

  group('CompanySettingsData', () {
    test('getCompanySettings ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getCompanySettings();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('updateCompanySettings ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.updateCompanySettings({'name': 'شركة'});

      verify(() => mockCrud.postData(any(), {'name': 'شركة'})).called(1);
    });

    test('getLeaveSettings ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getLeaveSettings();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('updateLeaveSettings ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.updateLeaveSettings(
        defaultAnnualLeaveDays: 21,
        carryoverEnabled: true,
        carryoverMaxDays: 5,
      );

      verify(() => mockCrud.postData(any(), {
        'default_annual_leave_days': 21,
        'carryover_enabled': true,
        'leave_carryover_max_days': 5,
        'carryover_expiry_months': null,
        'carryover_encash_excess': false,
        'carryover_legal_min_days': null,
        'auto_rollover_enabled': false,
        'apply_legal_seniority_entitlement': true,
      })).called(1);
    });

    test('runLeaveRollover ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.runLeaveRollover(2025);

      verify(() => mockCrud.postData(any(), {'from_year': 2025})).called(1);
    });
  });
}
