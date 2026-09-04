import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/leave_model.dart';

void main() {
  group('LeaveModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'employee_id': 5,
        'employee_name': 'أحمد',
        'type': 'annual',
        'start_date': '2024-06-01',
        'end_date': '2024-06-05',
        'reason': 'إجازة سنوية',
        'rejection_reason': null,
        'status': 'approved',
      };

      final leave = LeaveModel.fromJson(json);

      expect(leave.id, 1);
      expect(leave.employeeId, 5);
      expect(leave.employeeName, 'أحمد');
      expect(leave.type, 'annual');
      expect(leave.startDate, DateTime(2024, 6));
      expect(leave.endDate, DateTime(2024, 6, 5));
      expect(leave.reason, 'إجازة سنوية');
      expect(leave.rejectionReason, isNull);
      expect(leave.status, 'approved');
    });

    test('بيانات ناقصة/null', () {
      final leave = LeaveModel.fromJson({});

      expect(leave.id, 0);
      expect(leave.employeeId, 0);
      expect(leave.type, 'annual');
      expect(leave.endDate, isNull);
      expect(leave.reason, isNull);
      expect(leave.status, 'pending');
    });

    test('start_date مفقود يستخدم DateTime.now', () {
      final leave = LeaveModel.fromJson({});
      expect(leave.startDate, isNotNull);
    });

    test('end_date غير صالح يرجع null', () {
      final leave = LeaveModel.fromJson({
        'end_date': 'invalid-date',
      });
      expect(leave.endDate, isNull);
    });

    test('حالات مختلفة', () {
      for (final s in ['pending', 'approved', 'rejected']) {
        final leave = LeaveModel.fromJson({
          'start_date': '2024-01-01',
          'status': s,
        });
        expect(leave.status, s);
      }
    });

    test('أنواع إجازة مختلفة', () {
      for (final t in ['annual', 'sick', 'personal', 'unpaid', 'weekly_off', 'converted_from_absence']) {
        final leave = LeaveModel.fromJson({
          'start_date': '2024-01-01',
          'type': t,
        });
        expect(leave.type, t);
      }
    });
  });
}
