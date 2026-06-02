import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medjat_app/core/class/crud.dart';
import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/data/data_source/remote/station_data/station_data.dart';
import 'package:medjat_app/data/model/station_model.dart';

import '../../helpers/test_helpers.dart';

class MockStationData extends Mock implements StationData {}

void main() {
  late MockStationData mockStationData;

  setUp(() {
    setupGetTestBindings();
    registerFallbacks();
    mockStationData = MockStationData();
    Get.put<StationData>(mockStationData);
    Get.put<CRUD>(MockCRUD());
  });

  tearDown(() {
    Get.reset();
  });

  group('StationData', () {
    test('activate returns station token on success', () async {
      when(() => mockStationData.activate(
            qrPayload: any(named: 'qrPayload'),
            deviceInfo: any(named: 'deviceInfo'),
          )).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'token': 'station-token-123',
              'station': {
                'station_id': 1,
                'branch_id': 5,
                'branch_name': 'فرع الرياض',
                'device_name': 'Kiosk-1',
                'station_methods': 'fingerprint_only',
                'station_confidence_threshold': 0.7,
                'station_anti_spoofing_enabled': false,
                'station_gps_radius_meters': 100.0,
                'is_locked': false,
              },
            },
          });

      final response = await mockStationData.activate(
        qrPayload: 'test-qr',
        deviceInfo: {'device_id': 'test'},
      );

      expect(response['status'], StatusRequest.success);
      final data = response['data'] as Map<String, dynamic>;
      expect(data['token'], 'station-token-123');

      final station = Station.fromJson(data['station'] as Map<String, dynamic>);
      expect(station.branchName, 'فرع الرياض');
      expect(station.isLocked, false);
    });

    test('checkInOut 429 returns too_soon', () async {
      when(() => mockStationData.checkInOut(
            employeeId: any(named: 'employeeId'),
            method: any(named: 'method'),
            confidence: any(named: 'confidence'),
            gpsLat: any(named: 'gpsLat'),
            gpsLng: any(named: 'gpsLng'),
            capturedImageBase64: any(named: 'capturedImageBase64'),
          )).thenAnswer((_) async => {
            'status': StatusRequest.failure,
            'statusCode': 429,
            'message': 'too_soon',
          });

      final response = await mockStationData.checkInOut(
        employeeId: 1,
        method: 'fingerprint',
      );

      expect(response['statusCode'], 429);
      expect(response['message'], 'too_soon');
    });

    test('heartbeat locked returns locked status', () async {
      when(() => mockStationData.heartbeat()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'status': 'locked',
              'reason': 'GPS out of range',
            },
          });

      final response = await mockStationData.heartbeat();

      expect(response['status'], StatusRequest.success);
      final data = response['data'] as Map<String, dynamic>;
      expect(data['status'], 'locked');
      expect(data['reason'], 'GPS out of range');
    });
  });
}
