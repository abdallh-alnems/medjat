import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/document_data/document_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late DocumentData documentData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    documentData = DocumentData();
  });

  tearDown(() => teardownGetX());

  group('DocumentData', () {
    test('getDocuments ينادي getData مع employeeId', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await documentData.getDocuments(5);

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('uploadDocument ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await documentData.uploadDocument(5, {'file': 'test.pdf'});

      verify(() => mockCrud.postData(any(), {'file': 'test.pdf'})).called(1);
    });

    test('deleteDocument ينادي deleteData', () async {
      when(() => mockCrud.deleteData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await documentData.deleteDocument(5, 10);

      verify(() => mockCrud.deleteData(any())).called(1);
    });

    test('verifyDocument ينادي postData مع document_id', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await documentData.verifyDocument(10);

      verify(() => mockCrud.postData(any(), {'document_id': 10})).called(1);
    });

    test('rejectDocument ينادي postData مع reason', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await documentData.rejectDocument(10, 'غير واضح');

      verify(() => mockCrud.postData(any(), any())).called(1);
    });

    test('getMissingDocuments ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await documentData.getMissingDocuments(5);

      verify(() => mockCrud.getData(any())).called(1);
    });
  });
}
