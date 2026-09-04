import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/crud.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/tenant_data/tenant_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late TenantData tenantData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    tenantData = TenantData();
  });

  tearDown(() => teardownGetX());

  group('TenantData', () {
    test('createCompany ينادي postData مع token و company_name', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await tenantData.createCompany(
        firebaseToken: 'firebase_tok',
        companyName: 'شركة الاختبار',
      );

      verify(() => mockCrud.postData(any(), {
        'token': 'firebase_tok',
        'company_name': 'شركة الاختبار',
      })).called(1);
    });

    test('joinCompany ينادي postData مع token و invite_code', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await tenantData.joinCompany(
        firebaseToken: 'firebase_tok',
        inviteCode: 'ABC123',
      );

      verify(() => mockCrud.postData(any(), {
        'token': 'firebase_tok',
        'invite_code': 'ABC123',
      })).called(1);
    });
  });
}
