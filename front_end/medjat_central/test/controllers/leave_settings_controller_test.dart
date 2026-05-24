import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/company_settings_data/company_settings_data.dart';
import 'package:medjat_central/logic/controller/settings/leave_settings_controller.dart';
import '../helpers/test_helpers.dart';

class MockCompanySettingsData extends Mock implements CompanySettingsData {}

void main() {
  late MockCompanySettingsData mockData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockCompanySettingsData();
    Get.put<CompanySettingsData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('LeaveSettingsController', () {
    test('loadSettings — نجاح مع carryover', () async {
      when(() => mockData.getLeaveSettings()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'default_annual_leave_days': 21,
              'leave_carryover_max_days': 5,
            },
          });

      final controller = LeaveSettingsController();
      await controller.loadSettings();

      expect(controller.status, StatusRequest.success);
      expect(controller.defaultDaysController.text, '21');
      expect(controller.carryoverEnabled, isTrue);
      expect(controller.carryoverDaysController.text, '5');
    });

    test('loadSettings — نجاح بدون carryover', () async {
      when(() => mockData.getLeaveSettings()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'default_annual_leave_days': 30,
            },
          });

      final controller = LeaveSettingsController();
      await controller.loadSettings();

      expect(controller.defaultDaysController.text, '30');
      expect(controller.carryoverEnabled, isFalse);
    });

    test('loadSettings — فشل', () async {
      when(() => mockData.getLeaveSettings())
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      final controller = LeaveSettingsController();
      await controller.loadSettings();

      expect(controller.status, StatusRequest.serverFailure);
    });

    testWidgets('saveSettings — نجاح', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.getLeaveSettings()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'default_annual_leave_days': 21},
          });
      when(() => mockData.updateLeaveSettings(
            defaultAnnualLeaveDays: any(named: 'defaultAnnualLeaveDays'),
            carryoverMaxDays: any(named: 'carryoverMaxDays'),
          )).thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = LeaveSettingsController();
      await controller.loadSettings();

      await controller.saveSettings();

      verify(() => mockData.updateLeaveSettings(
            defaultAnnualLeaveDays: any(named: 'defaultAnnualLeaveDays'),
            carryoverMaxDays: any(named: 'carryoverMaxDays'),
          )).called(1);
      await settleSnackbars(tester);
    });

    testWidgets('runRollover — نجاح', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.getLeaveSettings()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'default_annual_leave_days': 21},
          });
      when(() => mockData.runLeaveRollover(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = LeaveSettingsController();
      await controller.loadSettings();

      await controller.runRollover(2025);

      verify(() => mockData.runLeaveRollover(2025)).called(1);
      expect(controller.rolloverRunning, isFalse);
      await settleSnackbars(tester);
    });

    test('setCarryoverEnabled يحدث القيمة', () async {
      when(() => mockData.getLeaveSettings()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'default_annual_leave_days': 21},
          });

      final controller = LeaveSettingsController();
      await controller.loadSettings();

      controller.setCarryoverEnabled(true);
      expect(controller.carryoverEnabled, isTrue);
    });
  });
}
