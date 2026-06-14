import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/live_attendance_data/live_attendance_data.dart';
import 'package:medjat_central/data/data_source/remote/branch_data/branch_data.dart';
import 'package:medjat_central/data/model/live_attendance_model.dart';
import 'package:medjat_central/logic/controller/live_attendance/live_attendance_controller.dart';
import '../helpers/test_helpers.dart';

class MockLiveAttendanceData extends Mock implements LiveAttendanceData {}

class MockBranchData extends Mock implements BranchData {}

void main() {
  late MockLiveAttendanceData mockLiveData;
  late MockBranchData mockBranchData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockLiveData = MockLiveAttendanceData();
    mockBranchData = MockBranchData();
    Get.put<LiveAttendanceData>(mockLiveData);
    Get.put<BranchData>(mockBranchData);
  });

  tearDown(() => teardownGetX());

  group('LiveAttendanceController', () {
    test('loadBoard — نجاح', () async {
      when(() => mockBranchData.getBranches()).thenAnswer(
          (_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockLiveData.getLiveBoard(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {
                  'employees': [
                    {
                      'employee_id': 1,
                      'name': 'أحمد',
                      'derived_status': 'in',
                    },
                  ],
                  'summary': {
                    'total': 1,
                    'in': 1,
                    'out': 0,
                    'not_in': 0,
                    'absent': 0,
                    'leave': 0,
                    'late': 0,
                  },
                  'server_time': '2025-06-01T10:00:00Z',
                },
              });

      final controller = LiveAttendanceController();
      await controller.loadBoard();

      expect(controller.status, StatusRequest.success);
      expect(controller.entries.length, 1);
      expect(controller.entries.first.name, 'أحمد');
      expect(controller.summary.total, 1);
      expect(controller.summary.inside, 1);
    });

    test('loadBoard — فشل', () async {
      when(() => mockBranchData.getBranches()).thenAnswer(
          (_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockLiveData.getLiveBoard(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {'status': StatusRequest.serverFailure});

      final controller = LiveAttendanceController();
      await controller.loadBoard();

      expect(controller.status, StatusRequest.serverFailure);
    });

    test('filteredEntries يفلتر بالاسم', () async {
      when(() => mockBranchData.getBranches()).thenAnswer(
          (_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockLiveData.getLiveBoard(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {
                  'employees': [
                    {'employee_id': 1, 'name': 'أحمد', 'derived_status': 'in'},
                    {'employee_id': 2, 'name': 'خالد', 'derived_status': 'out'},
                  ],
                  'summary': {'total': 2},
                },
              });

      final controller = LiveAttendanceController();
      await controller.loadBoard();

      controller.setSearch('أحمد');
      expect(controller.filteredEntries.length, 1);
      expect(controller.filteredEntries.first.name, 'أحمد');
    });

    test('filteredEntries يفلتر بالحالة', () async {
      when(() => mockBranchData.getBranches()).thenAnswer(
          (_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockLiveData.getLiveBoard(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {
                  'employees': [
                    {'employee_id': 1, 'name': 'أحمد', 'derived_status': 'in'},
                    {'employee_id': 2, 'name': 'خالد', 'derived_status': 'out'},
                  ],
                  'summary': {'total': 2},
                },
              });

      final controller = LiveAttendanceController();
      await controller.loadBoard();

      controller.setStatusFilter(LiveStatus.out);
      expect(controller.filteredEntries.length, 1);
      expect(controller.filteredEntries.first.name, 'خالد');
    });

    test('selectBranch يحدث selectedBranchId', () async {
      when(() => mockBranchData.getBranches()).thenAnswer(
          (_) async => {'status': StatusRequest.success, 'data': <Map<String, dynamic>>[]});
      when(() => mockLiveData.getLiveBoard(branchId: any(named: 'branchId')))
          .thenAnswer((_) async => {
                'status': StatusRequest.success,
                'data': {'employees': <Map<String, dynamic>>[], 'summary': <String, dynamic>{}},
              });

      final controller = LiveAttendanceController();
      await controller.loadBoard();

      controller.selectBranch(5);
      expect(controller.selectedBranchId, 5);
    });
  });
}
