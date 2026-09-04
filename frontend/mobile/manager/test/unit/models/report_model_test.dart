import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/report_model.dart';

void main() {
  group('AttendanceReportRow', () {
    test('بيانات كاملة', () {
      final json = {
        'employee_id': 1,
        'employee_name': 'أحمد',
        'job_title': 'مدير',
        'branch_name': 'الفرع',
        'days_present': 20,
        'days_late': 2,
        'days_absent': 1,
        'days_leave': 3,
        'days_recorded': 26,
        'total_minutes_worked': 12000,
      };

      final row = AttendanceReportRow.fromJson(json);

      expect(row.employeeId, 1);
      expect(row.employeeName, 'أحمد');
      expect(row.jobTitle, 'مدير');
      expect(row.branchName, 'الفرع');
      expect(row.daysPresent, 20);
      expect(row.daysLate, 2);
      expect(row.daysAbsent, 1);
      expect(row.daysLeave, 3);
      expect(row.daysRecorded, 26);
      expect(row.totalMinutesWorked, 12000);
      expect(row.hoursWorked, 200);
    });

    test('بيانات ناقصة', () {
      final row = AttendanceReportRow.fromJson({});

      expect(row.employeeId, 0);
      expect(row.employeeName, '');
      expect(row.daysPresent, 0);
      expect(row.hoursWorked, 0);
    });

    test('تحويل أنواع', () {
      final row = AttendanceReportRow.fromJson({
        'employee_id': '5',
        'employee_name': 'محمد',
        'total_minutes_worked': '90',
      });

      expect(row.employeeId, 5);
      expect(row.totalMinutesWorked, 90);
    });
  });

  group('AttendanceReportSummary', () {
    test('بيانات كاملة', () {
      final summary = AttendanceReportSummary.fromJson({
        'total_present': 100,
        'total_late': 10,
        'total_absent': 5,
        'total_leave': 3,
        'employees_with_records': 50,
      });

      expect(summary.totalPresent, 100);
      expect(summary.totalLate, 10);
      expect(summary.totalAbsent, 5);
      expect(summary.totalLeave, 3);
      expect(summary.employeesWithRecords, 50);
    });
  });

  group('PayrollReportRow', () {
    test('بيانات كاملة', () {
      final row = PayrollReportRow.fromJson({
        'id': 1,
        'employee_id': 5,
        'employee_name': 'أحمد',
        'job_title': 'مدير',
        'branch_name': 'فرع',
        'base_salary': 10000,
        'total_deductions': 500,
        'total_bonuses': 200,
        'overtime_total_minutes': 60,
        'net_salary': 9700,
        'status': 'approved',
      });

      expect(row.id, 1);
      expect(row.employeeId, 5);
      expect(row.baseSalary, 10000.0);
      expect(row.netSalary, 9700.0);
      expect(row.status, 'approved');
    });
  });

  group('PayrollReportSummary', () {
    test('بيانات كاملة', () {
      final summary = PayrollReportSummary.fromJson({
        'employee_count': 50,
        'draft_count': 10,
        'approved_count': 30,
        'paid_count': 10,
        'total_base': 500000,
        'total_deductions': 50000,
        'total_bonuses': 10000,
        'total_overtime_minutes': 5000,
        'total_net': 460000,
      });

      expect(summary.employeeCount, 50);
      expect(summary.totalNet, 460000.0);
    });
  });

  group('EmployeesReportRow', () {
    test('بيانات كاملة', () {
      final row = EmployeesReportRow.fromJson({
        'employee_id': 1,
        'employee_name': 'أحمد',
        'job_title': 'مدير',
        'phone': '0501234567',
        'base_salary': 10000,
        'hire_date': '2024-01-15',
        'status': 'active',
        'branch_name': 'فرع',
        'shift_name': 'صباحية',
        'days_present': 20,
        'days_late': 2,
        'days_absent': 1,
        'days_leave': 3,
        'total_minutes_worked': 9600,
      });

      expect(row.employeeId, 1);
      expect(row.baseSalary, 10000.0);
      expect(row.hireDate, '2024-01-15');
    });
  });

  group('LeavesReportRow', () {
    test('بيانات كاملة', () {
      final row = LeavesReportRow.fromJson({
        'id': 1,
        'employee_id': 5,
        'employee_name': 'أحمد',
        'branch_name': 'فرع',
        'type': 'annual',
        'start_date': '2024-06-01',
        'end_date': '2024-06-05',
        'reason': 'إجازة',
        'status': 'approved',
      });

      expect(row.id, 1);
      expect(row.type, 'annual');
      expect(row.startDate, '2024-06-01');
      expect(row.endDate, '2024-06-05');
      expect(row.status, 'approved');
    });
  });

  group('OvertimeLateRow', () {
    test('بيانات كاملة', () {
      final row = OvertimeLateRow.fromJson({
        'employee_id': 4,
        'employee_name': 'أحمد',
        'job_title': 'محاسب',
        'branch_name': 'الفرع الرئيسي',
        // MySQL SUM() comes back as a string over JSON.
        'overtime_minutes': '210',
        'overtime_days': 2,
        'late_minutes': '55',
        'late_days': 2,
        'worst_late_minutes': 35,
        'worked_minutes': '1170',
        'days_present': 4,
      });

      expect(row.employeeId, 4);
      expect(row.employeeName, 'أحمد');
      expect(row.overtimeMinutes, 210);
      expect(row.overtimeDays, 2);
      expect(row.lateMinutes, 55);
      expect(row.lateDays, 2);
      expect(row.worstLateMinutes, 35);
      expect(row.avgLateMinutes, 27);
    });

    test('بيانات ناقصة — لا قسمة على صفر', () {
      final row = OvertimeLateRow.fromJson({});

      expect(row.employeeId, 0);
      expect(row.employeeName, '');
      expect(row.overtimeMinutes, 0);
      expect(row.lateDays, 0);
      expect(row.avgLateMinutes, 0);
    });
  });

  group('OvertimeLateSummary', () {
    test('بيانات كاملة', () {
      final summary = OvertimeLateSummary.fromJson({
        'total_overtime_minutes': '210',
        'total_late_minutes': '55',
        'overtime_days': 2,
        'late_days': 2,
        'employees_with_overtime': 1,
        'employees_late': 1,
      });

      expect(summary.totalOvertimeMinutes, 210);
      expect(summary.totalLateMinutes, 55);
      expect(summary.overtimeDays, 2);
      expect(summary.employeesLate, 1);
    });

    test('بيانات ناقصة', () {
      final summary = OvertimeLateSummary.fromJson({});

      expect(summary.totalOvertimeMinutes, 0);
      expect(summary.employeesWithOvertime, 0);
    });
  });

  group('OvertimeLateDay', () {
    test('يوم فيه تأخير وإضافي', () {
      final day = OvertimeLateDay.fromJson({
        'date': '2026-06-25',
        'check_in_time': '09:20:00',
        'check_out_time': '18:30:00',
        'late_minutes': 20,
        'overtime_minutes': 30,
        'worked_minutes': 550,
        'notes': null,
      });

      expect(day.date, '2026-06-25');
      expect(day.checkInTime, '09:20:00');
      expect(day.lateMinutes, 20);
      expect(day.overtimeMinutes, 30);
      expect(day.notes, isNull);
    });
  });
}
