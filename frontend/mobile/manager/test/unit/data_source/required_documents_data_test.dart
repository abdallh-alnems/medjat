import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/crud.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/required_documents_data/required_documents_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late RequiredDocumentsData data;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    data = RequiredDocumentsData();
  });

  tearDown(() => teardownGetX());

  group('RequiredDocumentsData', () {
    test('getRequired ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getRequired();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('createRequired ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.createRequired({'name': 'إقامة'});

      verify(() => mockCrud.postData(any(), {'name': 'إقامة'})).called(1);
    });

    test('updateRequired ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.updateRequired({'id': 1, 'name': 'محدث'});

      verify(() => mockCrud.postData(any(), {'id': 1, 'name': 'محدث'})).called(1);
    });

    test('deleteRequired ينادي postData مع id', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.deleteRequired(5);

      verify(() => mockCrud.postData(any(), {'id': 5})).called(1);
    });

    test('toggleRequired ينادي postData مع id', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.toggleRequired(5);

      verify(() => mockCrud.postData(any(), {'id': 5})).called(1);
    });
  });
}
