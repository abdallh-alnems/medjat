import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/dashboard_data/dashboard_data.dart';
import 'package:medjat_central/data/model/dashboard_model.dart';
import 'package:medjat_central/logic/controller/dashboard/dashboard_controller.dart';
import '../helpers/test_helpers.dart';

class MockDashboardData extends Mock implements DashboardData {}

void main() {
  late MockDashboardData mockData;
  late DashboardController controller;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockDashboardData();
    Get.put<DashboardData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('DashboardController — تحميل البيانات', () {
    test('نجاح الجلب يملأ dashboard', () async {
      when(() => mockData.getDashboard()).thenAnswer((_) async => <String, dynamic>{
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
      when(() => mockData.getDashboard()).thenAnswer(
          (_) async => {'status': StatusRequest.serverFailure});

      controller = DashboardController();
      await controller.loadDashboard();

      expect(controller.status, StatusRequest.serverFailure);
      expect(controller.dashboard, isNull);
    });

    test('selectBranch يضبط selectedBranchId', () async {
      when(() => mockData.getDashboard()).thenAnswer((_) async => <String, dynamic>{
            'status': StatusRequest.success,
            'data': <String, dynamic>{'total_employees': 0},
          });
      when(() => mockData.getDashboardByBranch(any())).thenAnswer(
          (_) async => <String, dynamic>{
                'status': StatusRequest.success,
                'data': <String, dynamic>{'total_employees': 50},
              });

      controller = DashboardController();
      await controller.loadDashboard();

      controller.selectBranch(1);
      await controller.loadDashboard();

      expect(controller.selectedBranchId, 1);
      verify(() => mockData.getDashboardByBranch(1)).called(2);
    });

    test('selectMetric يحدث selectedMetric', () async {
      when(() => mockData.getDashboard()).thenAnswer((_) async => <String, dynamic>{
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
