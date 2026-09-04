import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permedjat_central/core/class/status_request.dart';
import 'package:permedjat_central/data/data_source/remote/dashboard_data/dashboard_data.dart';
import 'package:permedjat_central/data/data_source/remote/branch_data/branch_data.dart';
import 'package:permedjat_central/data/data_source/remote/category_data/category_data.dart';
import 'package:permedjat_central/data/data_source/remote/shift_data/shift_data.dart';
import 'package:permedjat_central/data/model/dashboard_model.dart';
import 'package:permedjat_central/logic/controller/dashboard/dashboard_controller.dart';
import '../helpers/test_helpers.dart';

class MockDashboardData extends Mock implements DashboardData {}
class MockBranchData extends Mock implements BranchData {}
class MockCategoryData extends Mock implements CategoryData {}
class MockShiftData extends Mock implements ShiftData {}

void main() {
  late MockDashboardData mockData;
  late DashboardController controller;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockDashboardData();
    Get.put<DashboardData>(mockData);
    Get.put<BranchData>(MockBranchData());
    Get.put<CategoryData>(MockCategoryData());
    Get.put<ShiftData>(MockShiftData());
  });

  tearDown(() => teardownGetX());

  group('DashboardController — تحميل البيانات', () {
    test('نجاح الجلب يملأ dashboard', () async {
      when(() => mockData.getDashboardFiltered()).thenAnswer((_) async => <String, dynamic>{
            'status': StatusRequest.success,
            'data': <String, dynamic>{
              'total_employees': 100,
              'present_today': 80,
              'absent_today': 10,
              'late_today': 5,
              'on_leave_today': 5,
              'branch_stats': <Map<String, dynamic>>[],
            },
          });

      controller = DashboardController();
      await controller.loadDashboard();

      expect(controller.status, StatusRequest.success);
      expect(controller.dashboard, isNotNull);
      expect(controller.dashboard!.totalEmployees, 100);
      expect(controller.dashboard!.presentToday, 80);
    });

    test('فشل الجلب', () async {
      when(() => mockData.getDashboardFiltered()).thenAnswer(
          (_) async => {'status': StatusRequest.serverFailure});

      controller = DashboardController();
      await controller.loadDashboard();

      expect(controller.status, StatusRequest.serverFailure);
      expect(controller.dashboard, isNull);
    });

    test('selectBranch يضبط selectedBranchId', () async {
      when(() => mockData.getDashboardFiltered()).thenAnswer((_) async => <String, dynamic>{
            'status': StatusRequest.success,
            'data': <String, dynamic>{'total_employees': 0},
          });
      when(() => mockData.getDashboardFiltered(branchId: any(named: 'branchId'))).thenAnswer(
          (_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'total_employees': 50},
              });

      controller = DashboardController();
      await controller.loadDashboard();

      controller.applyFilters(branchId: 1);
      await controller.loadDashboard();

      expect(controller.selectedBranchId, 1);
    });

    test('selectMetric يحدث selectedMetric', () async {
      when(() => mockData.getDashboardFiltered()).thenAnswer((_) async => <String, dynamic>{
            'status': StatusRequest.success,
            'data': <String, dynamic>{},
          });

      controller = DashboardController();
      await controller.loadDashboard();

      controller.selectMetric(BranchMetric.totalPayroll);

      expect(controller.selectedMetric, BranchMetric.totalPayroll);
    });
  });
}
