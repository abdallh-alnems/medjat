import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/crud.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/live_attendance_data/live_attendance_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late LiveAttendanceData data;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    data = LiveAttendanceData();
  });

  tearDown(() => teardownGetX());

  group('LiveAttendanceData', () {
    test('getLiveBoard بدون branchId', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getLiveBoard();

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('getLiveBoard مع branchId', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await data.getLiveBoard(branchId: 3);

      verify(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters'))).called(1);
    });
  });
}
