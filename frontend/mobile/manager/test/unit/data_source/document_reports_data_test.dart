import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/document_reports_data/document_reports_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late DocumentReportsData data;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    data = DocumentReportsData();
  });

  tearDown(() => teardownGetX());

  group('DocumentReportsData', () {
    test('getExpiringSoon ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getExpiringSoon(daysAhead: 60);

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getExpired ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getExpired();

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getMissing ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getMissing(branchId: 1);

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getStats ينادي getData', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getStats();

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('markExpired ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.markExpired();

      verify(() => mockCrud.postData(any(), {})).called(1);
    });
  });
}
