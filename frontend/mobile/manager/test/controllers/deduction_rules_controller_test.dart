import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/deduction_rule_data/deduction_rule_data.dart';
import 'package:permedjat_central/data/model/deduction_rule_model.dart';
import 'package:permedjat_central/logic/controller/settings/deduction_rules_controller.dart';
import '../helpers/test_helpers.dart';

class MockDeductionRuleData extends Mock implements DeductionRuleData {}

void main() {
  late MockDeductionRuleData mockData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    registerFallbackValue(<String, dynamic>{});
    mockData = MockDeductionRuleData();
    Get.put<DeductionRuleData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('DeductionRulesController', () {
    test('loadConfig — نجاح يحمّل الـ tiers و absenceDays', () async {
      when(() => mockData.getDeductionConfig()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'data': {
                'config': {
                  'tiers': [
                    {'threshold_minutes': 15, 'deduction_days': 0.25},
                    {'threshold_minutes': 30, 'deduction_days': 0.5},
                  ],
                  'absence_days': 2.0,
                }
              }
            },
          });

      final controller = DeductionRulesController();
      await controller.loadConfig();

      expect(controller.status, StatusRequest.success);
      expect(controller.tiers.length, 2);
      expect(controller.absenceDays, 2.0);
    });

    test('loadConfig — فشل يضبط status', () async {
      when(() => mockData.getDeductionConfig())
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      final controller = DeductionRulesController();
      await controller.loadConfig();

      expect(controller.status, StatusRequest.serverFailure);
    });

    testWidgets('upsertTier — يضيف tier جديد ويحفظ', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.getDeductionConfig()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'data': {'config': {'tiers': <Map<String, dynamic>>[], 'absence_days': 1.5}}
            },
          });
      when(() => mockData.saveDeductionConfig(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = DeductionRulesController();
      await controller.loadConfig();

      controller.upsertTier(const LateTier(thresholdMinutes: 20, deductionDays: 0.5));

      expect(controller.tiers.length, 1);
      expect(controller.tiers.first.thresholdMinutes, 20);
      await settleSnackbars(tester);
    });

    testWidgets('upsertTier — يرفض الـ threshold المكرر', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.getDeductionConfig()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'data': {
                'config': {
                  'tiers': [
                    {'threshold_minutes': 30, 'deduction_days': 0.5},
                  ],
                  'absence_days': 1.5,
                }
              }
            },
          });
      when(() => mockData.saveDeductionConfig(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = DeductionRulesController();
      await controller.loadConfig();

      final result = controller.upsertTier(
        const LateTier(thresholdMinutes: 30, deductionDays: 1.0),
      );

      expect(result, 'tier_duplicate');
      expect(controller.tiers.length, 1);
      await settleSnackbars(tester);
    });

    testWidgets('removeTier — يحذف من القائمة', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.getDeductionConfig()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'data': {
                'config': {
                  'tiers': [
                    {'threshold_minutes': 15, 'deduction_days': 0.25},
                    {'threshold_minutes': 30, 'deduction_days': 0.5},
                  ],
                  'absence_days': 1.5,
                }
              }
            },
          });
      when(() => mockData.saveDeductionConfig(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = DeductionRulesController();
      await controller.loadConfig();
      expect(controller.tiers.length, 2);

      controller.removeTier(controller.tiers.first);

      expect(controller.tiers.length, 1);
      expect(controller.tiers.first.thresholdMinutes, 30);
      await settleSnackbars(tester);
    });
  });
}
