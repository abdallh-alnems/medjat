import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/crud.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/attendance_data/attendance_data.dart';
import '../../helpers/test_helpers.dart';

class MockCRUD extends Mock implements CRUD {}

void main() {
  late MockCRUD mockCrud;
  late AttendanceData attendanceData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockCrud = MockCRUD();
    Get.put<CRUD>(mockCrud);
    attendanceData = AttendanceData();
  });

  tearDown(() => teardownGetX());

  group('AttendanceData', () {
    test('getAttendance ينادي getData مع endpoint الصحيح', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await attendanceData.getAttendance();

      verify(() => mockCrud.getData(
            any(that: contains('get_branch_attendance.php')),
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

    test('getAttendance مع فلاتر', () async {
      when(() => mockCrud.getData(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await attendanceData.getAttendance(
        date: '2024-06-01',
        branchId: 1,
        employeeId: 5,
      );

      verify(() => mockCrud.getData(
            any(that: contains('get_branch_attendance.php')),
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });

    test('manualCheckIn ينادي postData', () async {
      when(() => mockCrud.postData(any(), any()))
          .thenAnswer((_) async => {'status': StatusRequest.success, 'data': null});

      await attendanceData.manualCheckIn({'employee_id': 5, 'time': '08:00'});

      verify(() => mockCrud.postData(
            any(that: contains('manual_check_in.php')),
            {'employee_id': 5, 'time': '08:00'},
          )).called(1);
    });
  });
}
