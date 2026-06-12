import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/company_settings_data/company_settings_data.dart';
import 'package:medjat_central/logic/controller/settings/company_settings_controller.dart';
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

  group('CompanySettingsController', () {
    test('loadSettings — نجاح', () async {
      when(() => mockData.getCompanySettings()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'name': 'شركة الاختبار',
              'currency': 'SAR',
              'timezone': 'Asia/Riyadh',
              'has_logo': true,
              'cycle_start_day': 5,
            },
          });

      final controller = CompanySettingsController();
      await controller.loadSettings();

      expect(controller.status, StatusRequest.success);
      expect(controller.nameController.text, 'شركة الاختبار');
      expect(controller.currency, 'SAR');
      expect(controller.timezone, 'Asia/Riyadh');
      expect(controller.hasLogo, true);
      expect(controller.cycleStartDay, 5);
    });

    test('loadSettings — فشل', () async {
      when(() => mockData.getCompanySettings())
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      final controller = CompanySettingsController();
      await controller.loadSettings();

      expect(controller.status, StatusRequest.serverFailure);
    });

    testWidgets('saveSettings — نجاح', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.getCompanySettings()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'name': '', 'currency': 'EGP', 'timezone': 'Africa/Cairo'},
          });
      when(() => mockData.updateCompanySettings(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = CompanySettingsController();
      await controller.loadSettings();

      controller.nameController.text = 'اسم جديد';
      await controller.saveSettings();

      expect(controller.status, StatusRequest.success);
      verify(() => mockData.updateCompanySettings(any())).called(1);
      await settleSnackbars(tester);
    });
  });
}
