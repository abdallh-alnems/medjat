import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/deduction_rule_data/deduction_rule_data.dart';
import 'package:medjat_central/data/model/deduction_rule_model.dart';
import 'package:medjat_central/logic/controller/settings/deduction_rules_controller.dart';
import '../helpers/test_helpers.dart';

class MockDeductionRuleData extends Mock implements DeductionRuleData {}

void main() {
  late MockDeductionRuleData mockData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockDeductionRuleData();
    Get.put<DeductionRuleData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('DeductionRulesController', () {
    test('loadRules — نجاح', () async {
      when(() => mockData.getDeductionRules()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': [
              {'id': 1, 'name': 'خصم تأخير', 'type': 'late', 'amount': 50.0},
            ],
          });

      final controller = DeductionRulesController();
      await controller.loadRules();

      expect(controller.status, StatusRequest.success);
      expect(controller.rules.length, 1);
    });

    test('loadRules — فشل', () async {
      when(() => mockData.getDeductionRules())
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      final controller = DeductionRulesController();
      await controller.loadRules();

      expect(controller.status, StatusRequest.serverFailure);
    });

    testWidgets('deleteRule — نجاح يحذف من القائمة', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.getDeductionRules()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': [
              {'id': 1, 'name': 'خصم تأخير', 'type': 'late', 'amount': 50.0},
              {'id': 2, 'name': 'خصم غياب', 'type': 'absence', 'amount': 100.0},
            ],
          });
      when(() => mockData.deleteDeductionRule(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = DeductionRulesController();
      await controller.loadRules();
      expect(controller.rules.length, 2);

      await controller.deleteRule(1);

      expect(controller.rules.length, 1);
      expect(controller.rules.first.id, 2);
      await settleSnackbars(tester);
    });

    testWidgets('createRule — نجاح يعيد تحميل القواعد', (tester) async {
      await pumpSnackbarHost(tester);
      when(() => mockData.createDeductionRule(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});
      when(() => mockData.getDeductionRules())
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      final controller = DeductionRulesController();
      await controller.loadRules();

      await controller.createRule({'name': 'قاعدة جديدة'});

      verify(() => mockData.getDeductionRules()).called(2);
      await settleSnackbars(tester);
    });
  });
}
