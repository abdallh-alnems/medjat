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
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    data = DeductionRuleData();
  });

  tearDown(() => teardownGetX());

  group('DeductionRuleData', () {
    test('getDeductionRules ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getDeductionRules();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('createDeductionRule ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.createDeductionRule({'name': 'خصم تأخير'});

      verify(() => mockCrud.postData(any(), {'name': 'خصم تأخير'})).called(1);
    });

    test('updateDeductionRule ينادي putData', () async {
      when(() => mockCrud.putData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.updateDeductionRule(3, {'name': 'محدث'});

      verify(() => mockCrud.putData(any(), {'name': 'محدث'})).called(1);
    });

    test('deleteDeductionRule ينادي deleteData', () async {
      when(() => mockCrud.deleteData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.deleteDeductionRule(5);

      verify(() => mockCrud.deleteData(any())).called(1);
    });
  });
}
