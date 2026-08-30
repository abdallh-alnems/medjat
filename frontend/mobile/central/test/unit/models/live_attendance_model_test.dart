import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/live_attendance_model.dart';

void main() {
  group('liveStatusFromString', () {
    test('in → inside', () {
      expect(liveStatusFromString('in'), LiveStatus.inside);
    });

    test('out → out', () {
      expect(liveStatusFromString('out'), LiveStatus.out);
    });

    test('not_in → notIn', () {
      expect(liveStatusFromString('not_in'), LiveStatus.notIn);
    });

    test('absent → absent', () {
      expect(liveStatusFromString('absent'), LiveStatus.absent);
    });

    test('leave → leave', () {
      expect(liveStatusFromString('leave'), LiveStatus.leave);
    });

    test('null → unknown', () {
      expect(liveStatusFromString(null), LiveStatus.unknown);
    });

    test('قيمة غير معروفة → unknown', () {
      expect(liveStatusFromString('xyz'), LiveStatus.unknown);
    });
  });

  group('LiveAttendanceEntry.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'employee_id': 1,
        'name': 'أحمد',
        'job_title': 'مهندس',
        'branch_id': 3,
        'branch_name': 'الفرع الرئيسي',
        'derived_status': 'in',
        'check_in_time': '08:00',
        'check_out_time': '17:00',
        'late_minutes': 10,
        'is_late': true,
        'check_in_method': 'face',
        'is_offline': false,
      };

      final entry = LiveAttendanceEntry.fromJson(json);

      expect(entry.employeeId, 1);
      expect(entry.name, 'أحمد');
      expect(entry.jobTitle, 'مهندس');
      expect(entry.branchId, 3);
      expect(entry.branchName, 'الفرع الرئيسي');
      expect(entry.status, LiveStatus.inside);
      expect(entry.checkInTime, '08:00');
      expect(entry.checkOutTime, '17:00');
      expect(entry.lateMinutes, 10);
      expect(entry.isLate, isTrue);
      expect(entry.checkInMethod, 'face');
      expect(entry.isOffline, isFalse);
    });

    test('بيانات ناقصة', () {
      final entry = LiveAttendanceEntry.fromJson({});

      expect(entry.employeeId, 0);
      expect(entry.name, '');
      expect(entry.jobTitle, isNull);
      expect(entry.branchId, isNull);
      expect(entry.status, LiveStatus.unknown);
      expect(entry.lateMinutes, 0);
      expect(entry.isLate, isFalse);
      expect(entry.isOffline, isFalse);
    });
  });

  group('LiveAttendanceSummary.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'total': 100,
        'in': 60,
        'out': 10,
        'not_in': 5,
        'absent': 15,
        'leave': 5,
        'late': 5,
      };

      final summary = LiveAttendanceSummary.fromJson(json);

      expect(summary.total, 100);
      expect(summary.inside, 60);
      expect(summary.out, 10);
      expect(summary.notIn, 5);
      expect(summary.absent, 15);
      expect(summary.leave, 5);
      expect(summary.late, 5);
    });

    test('بيانات ناقصة تعطي أصفار', () {
      final summary = LiveAttendanceSummary.fromJson({});

      expect(summary.total, 0);
      expect(summary.inside, 0);
      expect(summary.out, 0);
      expect(summary.notIn, 0);
      expect(summary.absent, 0);
      expect(summary.leave, 0);
      expect(summary.late, 0);
    });
  });
}
