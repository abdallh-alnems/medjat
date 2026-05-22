import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/station_data/station_data.dart';
import 'package:medjat_central/data/data_source/remote/branch_data/branch_data.dart';
import 'package:medjat_central/data/model/attendance_station_model.dart';
import 'package:medjat_central/logic/controller/station/stations_controller.dart';
import '../helpers/test_helpers.dart';

class MockStationData extends Mock implements StationData {}

class MockBranchData extends Mock implements BranchData {}

void main() {
  late MockStationData mockStationData;
  late MockBranchData mockBranchData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockStationData = MockStationData();
    mockBranchData = MockBranchData();
    Get.put<StationData>(mockStationData);
    Get.put<BranchData>(mockBranchData);
  });

  tearDown(() => teardownGetX());

  group('StationsController', () {
    test('load — نجاح', () async {
      when(() => mockStationData.getStations(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {
                  'items': [
                    {'id': 1, 'branch_id': 5, 'branch_name': 'الفرع', 'device_name': 'جهاز 1', 'device_token': 't1', 'is_activated': 1, 'is_active': 1, 'is_locked': 0},
                  ],
                },
              });
      when(() => mockBranchData.getBranches())
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      final controller = StationsController();
      await controller.load();

      expect(controller.status, StatusRequest.success);
      expect(controller.stations.length, 1);
      expect(controller.stations.first.deviceName, 'جهاز 1');
    });

    test('deleteStation — نجاح يعيد true', () async {
      when(() => mockStationData.getStations(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': {'items': []}});
      when(() => mockBranchData.getBranches())
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});
      when(() => mockStationData.deleteStation(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = StationsController();
      await controller.load();

      final result = await controller.deleteStation(5);

      expect(result, isTrue);
    });

    test('deleteStation — فشل يعيد false', () async {
      when(() => mockStationData.getStations(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': {'items': []}});
      when(() => mockBranchData.getBranches())
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});
      when(() => mockStationData.deleteStation(any()))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      final controller = StationsController();
      await controller.load();

      final result = await controller.deleteStation(5);

      expect(result, isFalse);
    });

    test('toggleActive — نجاح يعيد true', () async {
      when(() => mockStationData.getStations(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': {'items': []}});
      when(() => mockBranchData.getBranches())
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});
      when(() => mockStationData.updateStation(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = StationsController();
      await controller.load();

      final result = await controller.toggleActive(1, false);

      expect(result, isTrue);
    });

    test('regenerateQR — نجاح', () async {
      when(() => mockStationData.getStations(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': {'items': []}});
      when(() => mockBranchData.getBranches())
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});
      when(() => mockStationData.regenerateQR(any()))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {'qr_payload': 'new_qr'},
              });

      final controller = StationsController();
      await controller.load();

      final result = await controller.regenerateQR(1);

      expect(result, isNotNull);
    });

    test('setFilter يحدث filterBranchId', () async {
      when(() => mockStationData.getStations(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': {'items': []}});
      when(() => mockBranchData.getBranches())
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': []});

      final controller = StationsController();
      await controller.load();

      controller.setFilter(5);

      expect(controller.filterBranchId, 5);
    });
  });
}
