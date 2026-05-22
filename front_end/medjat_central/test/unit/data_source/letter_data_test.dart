import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/letter_data/letter_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late LetterData letterData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    letterData = LetterData();
  });

  tearDown(() => teardownGetX());

  group('LetterData', () {
    test('getTemplates ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await letterData.getTemplates();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('createTemplate ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await letterData.createTemplate({'name_ar': 'خطاب'});

      verify(() => mockCrud.postData(any(), {'name_ar': 'خطاب'})).called(1);
    });

    test('updateTemplate ينادي postData مع template_id', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await letterData.updateTemplate(3, {'name_ar': 'محدث'});

      verify(() => mockCrud.postData(any(), any())).called(1);
    });

    test('deleteTemplate ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await letterData.deleteTemplate(5);

      verify(() => mockCrud.postData(any(), any())).called(1);
    });

    test('getRequests ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await letterData.getRequests();

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('issueDocument ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await letterData.issueDocument(employeeId: 1, templateId: 2);

      verify(() => mockCrud.postData(any(), any())).called(1);
    });

    test('approveRequest ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await letterData.approveRequest(5);

      verify(() => mockCrud.postData(any(), any())).called(1);
    });

    test('rejectRequest ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await letterData.rejectRequest(5, reason: 'غير مقبول');

      verify(() => mockCrud.postData(any(), any())).called(1);
    });

    test('downloadPdf ينادي getBytes', () async {
      when(() => mockCrud.getBytes(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await letterData.downloadPdf(5);

      verify(() => mockCrud.getBytes(any())).called(1);
    });
  });
}
