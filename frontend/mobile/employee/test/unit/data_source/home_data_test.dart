import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medjat_app/core/class/crud.dart';
import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/core/constant/id/app_links.dart';
import 'package:medjat_app/data/data_source/remote/home_data/home_data.dart';

import '../../helpers/test_helpers.dart';

void main() {
  late MockCRUD mockCrud;
  late HomeData homeData;

  setUp(() {
    setupGetTestBindings();
    setupDotenvForTest();
    registerFallbacks();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    homeData = HomeData();
  });

  tearDown(() {
    Get.reset();
  });

  group('HomeData', () {
    test('getAttendanceMonth sends correct month parameter', () async {
      when(() => mockCrud.getData(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {'records': <Map<String, dynamic>>[]},
          });

      final result = await homeData.getAttendanceMonth('2026-05');

      expect(result['status'], StatusRequest.success);
      verify(() => mockCrud.getData(AppLinks.attendanceMonth('2026-05')))
          .called(1);
    });

    test('getAttendanceMonth returns records from response', () async {
      when(() => mockCrud.getData(any())).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'records': [
                {'date': '2026-05-21', 'check_in_time': '08:30:00'},
              ],
            },
          });

      final result = await homeData.getAttendanceMonth('2026-05');

      expect(result['status'], StatusRequest.success);
      final data = result['data'] as Map<String, dynamic>;
      final records = data['records'] as List;
      expect(records.length, 1);
    });

    test('getAttendanceMonth returns offline when no connectivity', () async {
      when(() => mockCrud.getData(any())).thenAnswer((_) async => {
            'status': StatusRequest.offline,
          });

      final result = await homeData.getAttendanceMonth('2026-05');

      expect(result['status'], StatusRequest.offline);
    });
  });
}
