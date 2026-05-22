import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/station_data/station_data.dart';
import 'package:medjat_central/data/data_source/remote/branch_data/branch_data.dart';
import 'package:medjat_central/logic/controller/station/station_settings_controller.dart';
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

  group('StationSettingsController', () {
    test('loadSettings — نجاح', () async {
      when(() => mockBranchData.getBranch(any()))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {
                  'id': 1,
                  'name': 'الفرع',
                  'station_enabled': 1,
                  'station_methods': 'face_only',
                  'station_gps_radius_meters': 30,
                  'station_confidence_threshold': 0.85,
                  'station_anti_spoofing_enabled': 1,
                  'station_admin_pin_hash': 'hash',
                },
              });

      final controller = StationSettingsController();
      controller.init(1);
      await controller.loadSettings();

      expect(controller.status, StatusRequest.success);
      expect(controller.settings.enabled, isTrue);
      expect(controller.settings.antiSpoofing, isTrue);
      expect(controller.settings.hasAdminPin, isTrue);
    });

    test('loadSettings — فشل', () async {
      when(() => mockBranchData.getBranch(any()))
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      final controller = StationSettingsController();
      controller.init(1);
      await controller.loadSettings();

      expect(controller.status, StatusRequest.failure);
    });

    test('saveSettings — نجاح يعيد true', () async {
      when(() => mockBranchData.getBranch(any()))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {
                  'id': 1,
                  'name': 'الفرع',
                  'station_enabled': 1,
                  'station_methods': 'face_only',
                  'station_gps_radius_meters': 30,
                  'station_confidence_threshold': 0.85,
                  'station_anti_spoofing_enabled': 0,
                },
              });
      when(() => mockStationData.updateBranchSettings(any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      final controller = StationSettingsController();
      controller.init(1);
      await controller.loadSettings();

      final result = await controller.saveSettings(
        enabled: true,
        methods: 'face_fingerprint',
        gpsRadius: 50,
      );

      expect(result, isTrue);
    });

    test('saveSettings — فشل يعيد false', () async {
      when(() => mockBranchData.getBranch(any()))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {
                  'id': 1,
                  'name': 'الفرع',
                  'station_enabled': 0,
                },
              });
      when(() => mockStationData.updateBranchSettings(any()))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      final controller = StationSettingsController();
      controller.init(1);
      await controller.loadSettings();

      final result = await controller.saveSettings(enabled: true);

      expect(result, isFalse);
    });
  });
}
