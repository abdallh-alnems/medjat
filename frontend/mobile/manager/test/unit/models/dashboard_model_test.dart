import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/dashboard_model.dart';

void main() {
  group('DashboardModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'total_employees': 100,
        'present_today': 80,
        'absent_today': 10,
        'late_today': 5,
        'on_leave_today': 5,
        'branch_stats': [
          {
            'branch_id': 1,
            'branch_name': 'الفرع الرئيسي',
            'total_employees': 50,
            'present': 40,
            'absent': 5,
            'attendance_rate': 80.0,
            'total_payroll': 500000.0,
            'late': 3,
            'late_rate': 6.0,
          },
        ],
      };

      final dashboard = DashboardModel.fromJson(json);

      expect(dashboard.totalEmployees, 100);
      expect(dashboard.presentToday, 80);
      expect(dashboard.absentToday, 10);
      expect(dashboard.lateToday, 5);
      expect(dashboard.onLeaveToday, 5);
      expect(dashboard.branchStats.length, 1);
      expect(dashboard.branchStats.first.branchName, 'الفرع الرئيسي');
    });

    test('بيانات ناقصة/null', () {
      final dashboard = DashboardModel.fromJson({});

      expect(dashboard.totalEmployees, 0);
      expect(dashboard.presentToday, 0);
      expect(dashboard.absentToday, 0);
      expect(dashboard.lateToday, 0);
      expect(dashboard.onLeaveToday, 0);
      expect(dashboard.branchStats, isEmpty);
    });

    test('attendanceRate يحسب النسبة', () {
      final dashboard = DashboardModel.fromJson({
        'total_employees': 100,
        'active_in_scope': 100,
        'present_today': 80,
      });

      expect(dashboard.attendanceRate, 80.0);
    });

    test('attendanceRate مع totalEmployees = 0', () {
      final dashboard = DashboardModel.fromJson({});

      expect(dashboard.attendanceRate, 0);
    });
  });

  group('BranchStats', () {
    test('effectiveLateRate يستخدم lateRate إن >= 0', () {
      final stats = BranchStats.fromJson({
        'branch_id': 1,
        'branch_name': 'فرع',
        'late_rate': 5.0,
      });

      expect(stats.effectiveLateRate, 5.0);
    });

    test('effectiveLateRate يحسب من late/totalEmployees إن lateRate < 0', () {
      final stats = BranchStats.fromJson({
        'branch_id': 1,
        'branch_name': 'فرع',
        'total_employees': 100,
        'late': 10,
      });

      expect(stats.effectiveLateRate, 10.0);
    });

    test('effectiveLateRate مع totalEmployees = 0 و lateRate < 0', () {
      final stats = BranchStats.fromJson({
        'branch_id': 1,
        'branch_name': 'فرع',
        'total_employees': 0,
        'late': 0,
      });

      expect(stats.effectiveLateRate, 0);
    });

    test('valueForMetric يعيد القيمة الصحيحة', () {
      final stats = BranchStats.fromJson({
        'branch_id': 1,
        'branch_name': 'فرع',
        'total_employees': 50,
        'attendance_rate': 80.0,
        'total_payroll': 500000.0,
        'late_rate': 6.0,
      });

      expect(stats.valueForMetric(BranchMetric.attendanceRate), 80.0);
      expect(stats.valueForMetric(BranchMetric.totalPayroll), 500000.0);
      expect(stats.valueForMetric(BranchMetric.lateRate), 6.0);
      expect(stats.valueForMetric(BranchMetric.employeesCount), 50.0);
    });
  });
}
