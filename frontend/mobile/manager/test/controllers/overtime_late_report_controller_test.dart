import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:medjat_central/core/class/status_request.dart';
import 'package:medjat_central/data/data_source/remote/report_data/report_data.dart';
import 'package:medjat_central/logic/controller/report/overtime_late_report_controller.dart';
import '../helpers/test_helpers.dart';

class MockReportData extends Mock implements ReportData {}

Map<String, dynamic> _successPayload({List<dynamic>? days}) => {
      'status': StatusRequest.success,
      'data': {
        'data': {
          'start_date': '2026-06-01',
          'end_date': '2026-06-30',
          'items': [
            {
              'employee_id': 1,
              'employee_name': 'أحمد',
              'overtime_minutes': '120',
              'overtime_days': 1,
              'late_minutes': '35',
              'late_days': 1,
              'worst_late_minutes': 35,
            },
          ],
          'summary': {
            'total_overtime_minutes': '120',
            'total_late_minutes': '35',
            'overtime_days': 1,
            'late_days': 1,
            'employees_with_overtime': 1,
            'employees_late': 1,
          },
          if (days != null) 'days': days,
        },
      },
    };

void main() {
  late MockReportData mockData;

  setUp(() {
    setupTestBinding();
    setupGetX();
    mockData = MockReportData();
    Get.put<ReportData>(mockData);
  });

  tearDown(() => teardownGetX());

  group('OvertimeLateReportController', () {
    test('loadReport — نجاح يملأ الصفوف والملخص', () async {
      when(() => mockData.getOvertimeLateReport(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            branchId: any(named: 'branchId'),
            employeeId: any(named: 'employeeId'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => _successPayload());

      final controller = OvertimeLateReportController();
      await controller.loadReport();

      expect(controller.status, StatusRequest.success);
      expect(controller.rows.length, 1);
      expect(controller.rows.first.overtimeMinutes, 120);
      expect(controller.summary.totalLateMinutes, 35);
    });

    test('loadReport — فشل', () async {
      when(() => mockData.getOvertimeLateReport(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            branchId: any(named: 'branchId'),
            employeeId: any(named: 'employeeId'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => {'status': StatusRequest.failure});

      final controller = OvertimeLateReportController();
      await controller.loadReport();

      expect(controller.status, StatusRequest.failure);
      expect(controller.rows, isEmpty);
    });

    test('setSort — يغيّر الترتيب ويعيد التحميل مرة واحدة فقط', () async {
      when(() => mockData.getOvertimeLateReport(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            branchId: any(named: 'branchId'),
            employeeId: any(named: 'employeeId'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => _successPayload());

      final controller = OvertimeLateReportController();
      controller.setSort('late');
      // Same value again must not fire a second request.
      controller.setSort('late');
      await Future<void>.delayed(Duration.zero);

      expect(controller.sort, 'late');
      verify(() => mockData.getOvertimeLateReport(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            branchId: any(named: 'branchId'),
            employeeId: any(named: 'employeeId'),
            sort: 'late',
          )).called(1);
    });

    test('loadDays — يجلب أيام موظف واحد', () async {
      when(() => mockData.getOvertimeLateReport(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            branchId: any(named: 'branchId'),
            employeeId: any(named: 'employeeId'),
            sort: any(named: 'sort'),
          )).thenAnswer((_) async => _successPayload(days: [
            {
              'date': '2026-06-25',
              'check_in_time': '09:20:00',
              'check_out_time': '18:30:00',
              'late_minutes': 20,
              'overtime_minutes': 30,
              'worked_minutes': 550,
            },
          ]));

      final controller = OvertimeLateReportController();
      await controller.loadDays(9);

      expect(controller.daysStatus, StatusRequest.success);
      expect(controller.days.length, 1);
      expect(controller.days.first.lateMinutes, 20);
      verify(() => mockData.getOvertimeLateReport(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            branchId: any(named: 'branchId'),
            employeeId: 9,
            sort: any(named: 'sort'),
          )).called(1);
    });
  });
}
