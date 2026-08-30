import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/deduction_rule_data/deduction_rule_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late DeductionRuleData data;

  setUp(() {
    setupTestBinding();
    setupGetX();
    registerFallbackValue(<String, dynamic>{});
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    data = DeductionRuleData();
  });

  tearDown(() => teardownGetX());

  group('DeductionRuleData', () {
    test('getDeductionConfig ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getDeductionConfig();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('saveDeductionConfig ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final payload = {
        'absence_days': 1.5,
        'tiers': [
          {'threshold_minutes': 15, 'deduction_days': 0.25},
        ],
      };
      await data.saveDeductionConfig(payload);

      verify(() => mockCrud.postData(any(), payload)).called(1);
    });
  });
}
