import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/crud.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/station_data/station_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late StationData stationData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    stationData = StationData();
  });

  tearDown(() => teardownGetX());

  group('StationData', () {
    test('createStation ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await stationData.createStation({'device_name': 'جهاز 1'});

      verify(() => mockCrud.postData(any(), {'device_name': 'جهاز 1'})).called(1);
    });

    test('getStations ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await stationData.getStations();

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getStation ينادي getData مع id', () async {
      when(() => mockCrud.getData(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await stationData.getStation(5);

      verify(() => mockCrud.getData(any())).called(1);
    });

    test('updateStation ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await stationData.updateStation(3, {'name': 'محدث'});

      verify(() => mockCrud.postData(any(), any())).called(1);
    });

    test('deleteStation ينادي postData مع id', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await stationData.deleteStation(5);

      verify(() => mockCrud.postData(any(), {'id': 5})).called(1);
    });

    test('regenerateQR ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await stationData.regenerateQR(5);

      verify(() => mockCrud.postData(any(), {'id': 5})).called(1);
    });

    test('unlockStation ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await stationData.unlockStation(5);

      verify(() => mockCrud.postData(any(), {'id': 5})).called(1);
    });

    test('getLogs ينادي getData', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await stationData.getLogs();

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('updateBranchSettings ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await stationData.updateBranchSettings({'station_enabled': 1});

      verify(() => mockCrud.postData(any(), {'station_enabled': 1})).called(1);
    });
  });
}
