import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/attendance_model.dart';

void main() {
  group('AttendanceRecordModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 10,
        'employee_id': 5,
        'employee_name': 'محمد',
        'date': '2024-06-01',
        'check_in': '2024-06-01T08:30:00',
        'check_out': '2024-06-01T17:00:00',
        'status': 'present',
        'late_minutes': 30,
        'overtime_minutes': 60,
        'note': 'تأخير بسبب الزحام',
      };

      final rec = AttendanceRecordModel.fromJson(json);

      expect(rec.id, 10);
      expect(rec.employeeId, 5);
      expect(rec.employeeName, 'محمد');
      expect(rec.date, '2024-06-01');
      expect(rec.checkIn, DateTime(2024, 6, 1, 8, 30));
      expect(rec.checkOut, DateTime(2024, 6, 1, 17));
      expect(rec.status, 'present');
      expect(rec.lateMinutes, 30.0);
      expect(rec.overtimeMinutes, 60.0);
      expect(rec.note, 'تأخير بسبب الزحام');
    });

    test('بيانات ناقصة/null', () {
      final rec = AttendanceRecordModel.fromJson({});

      expect(rec.id, 0);
      expect(rec.employeeId, 0);
      expect(rec.employeeName, isNull);
      expect(rec.date, isNull);
      expect(rec.checkIn, isNull);
      expect(rec.checkOut, isNull);
      expect(rec.status, 'present');
      expect(rec.lateMinutes, isNull);
      expect(rec.overtimeMinutes, isNull);
    });

    test('تحويل num إلى double', () {
      final rec = AttendanceRecordModel.fromJson({
        'late_minutes': 30,
        'overtime_minutes': 60,
      });

      expect(rec.lateMinutes, 30.0);
      expect(rec.overtimeMinutes, 60.0);
    });

    test('تواريخ غير صالحة لا ترمي', () {
      final rec = AttendanceRecordModel.fromJson({
        'check_in': 'invalid',
        'check_out': 'invalid',
      });

      expect(rec.checkIn, isNull);
      expect(rec.checkOut, isNull);
    });

    test('حالات مختلفة', () {
      for (final s in ['present', 'absent', 'late', 'leave', 'half_day']) {
        final rec = AttendanceRecordModel.fromJson({'status': s});
        expect(rec.status, s);
      }
    });
  });
}
