import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/asset_data/asset_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late AssetData assetData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    assetData = AssetData();
  });

  tearDown(() => teardownGetX());

  group('AssetData', () {
    test('getAssets ينادي getData بدون فلتر', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await assetData.getAssets();

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getAssets مع status filter', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await assetData.getAssets(status: 'assigned');

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('createAsset ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await assetData.createAsset({'name': 'لابتوب'});

      verify(() => mockCrud.postData(any(), {'name': 'لابتوب'})).called(1);
    });

    test('approveReturn ينادي postData مع id', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await assetData.approveReturn(5);

      verify(() => mockCrud.postData(any(), {'id': 5})).called(1);
    });

    test('rejectReturn مع reason', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await assetData.rejectReturn(5, reason: 'غير صالح');

      verify(() => mockCrud.postData(any(), any(that: isNotNull))).called(1);
    });
  });
}
