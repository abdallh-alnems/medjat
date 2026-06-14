import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medjat_app/core/class/crud.dart';
import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/core/constant/id/app_links.dart';
import 'package:medjat_app/data/data_source/remote/attendance_data/attendance_data.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockCRUD mockCrud;
  late AttendanceData attendanceData;

  setUp(() {
    setupGetTestBindings();
    setupDotenvForTest();
    registerFallbacks();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    attendanceData = AttendanceData();
  });

  tearDown(() {
    Get.reset();
  });

  group('AttendanceData', () {
    test('checkIn sends correct parameters', () async {
      when(() => mockCrud.postData(any(), any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'id': 1},
          });

      final result = await attendanceData.checkIn(
        branchId: 5,
        latitude: 24.7136,
        longitude: 46.6753,
        qrCode: 'QR123',
      );

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.postData(AppLinks.checkIn, {
            'branch_id': 5,
            'latitude': 24.7136,
            'longitude': 46.6753,
            'qr_code': 'QR123',
            'is_vpn': 0,
          })).called(1);
    });

    test('checkOut sends empty body', () async {
      when(() => mockCrud.postData(any(), any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': null,
          });

      final result = await attendanceData.checkOut();

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.postData(AppLinks.checkOut, {})).called(1);
    });

    test('syncOffline sends records list', () async {
      final records = [
        {'client_record_id': '1', 'branch_id': 5},
        {'client_record_id': '2', 'branch_id': 5},
      ];

      when(() => mockCrud.postData(any(), any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'results': <Map<String, dynamic>>[]},
          });

      final result = await attendanceData.syncOffline(records);

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.postData(
            AppLinks.attendanceSync,
            {'records': records},
          )).called(1);
    });

    test('checkIn returns failure when CRUD fails', () async {
      when(() => mockCrud.postData(any(), any())).thenAnswer((_) async => {
            'status': StatusRequest.failure,
            'statusCode': 400,
            'message': 'أنت خارج نطاق الفرع',
          });

      final result = await attendanceData.checkIn(
        branchId: 1,
        latitude: 0,
        longitude: 0,
        qrCode: 'bad',
      );

      expect(result['status'], StatusRequest.failure);
      expect(result['statusCode'], 400);
    });
  });
}
