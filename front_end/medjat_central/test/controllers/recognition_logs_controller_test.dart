import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/station_data/station_data.dart';
import 'package:medjat_central/data/model/station_recognition_log_model.dart';
import 'package:medjat_central/logic/controller/station/recognition_logs_controller.dart';
import '../helpers/test_helpers.dart';

class MockStationData extends Mock implements StationData {}

void main() {
  late MockStationData mockData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockStationData();
    Get.put<StationData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('RecognitionLogsController', () {
    test('load — نجاح', () async {
      when(() => mockData.getLogs(filters: any(named: 'filters')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {
                  'total': 1,
                  'page': 1,
                  'items': [
                    {
                      'id': 1,
                      'station_id': 5,
                      'verification_method': 'face',
                      'result': 'success',
                      'created_at': '2025-06-01T08:00:00Z',
                    },
                  ],
                },
              });

      final controller = RecognitionLogsController();
      await controller.load();

      expect(controller.status, StatusRequest.success);
      expect(controller.logs.length, 1);
      expect(controller.total, 1);
    });

    test('load — فشل', () async {
      when(() => mockData.getLogs(filters: any(named: 'filters')))
          .thenAnswer((_) async => {'status': StatusRequest.failure});

      final controller = RecognitionLogsController();
      await controller.load();

      expect(controller.status, StatusRequest.failure);
    });

    test('setFilters يعيد التحميل بالفلاتر الجديدة', () async {
      when(() => mockData.getLogs(filters: any(named: 'filters')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {'total': 0, 'items': []},
              });

      final controller = RecognitionLogsController();
      await controller.load();

      controller.setFilters(
        branchId: 5,
        result: 'success',
      );

      expect(controller.filterBranchId, 5);
      expect(controller.filterResult, 'success');
      expect(controller.page, 1);
    });

    test('setPage يحدث الصفحة', () async {
      when(() => mockData.getLogs(filters: any(named: 'filters')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {'total': 50, 'page': 2, 'items': []},
              });

      final controller = RecognitionLogsController();
      await controller.load();

      controller.setPage(2);

      expect(controller.page, 2);
    });
  });
}
