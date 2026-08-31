import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/shift_model.dart';

void main() {
  group('ShiftModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'tenant_id': 10,
        'branch_id': 2,
        'branch_name': 'الفرع الرئيسي',
        'name': 'الوردية الصباحية',
        'start_time': '08:00:00',
        'end_time': '16:00:00',
        'is_active': 1,
        'employee_count': 25,
      };

      final shift = ShiftModel.fromJson(json);

      expect(shift.id, 1);
      expect(shift.tenantId, 10);
      expect(shift.branchId, 2);
      expect(shift.branchName, 'الفرع الرئيسي');
      expect(shift.name, 'الوردية الصباحية');
      expect(shift.startTime, '08:00:00');
      expect(shift.endTime, '16:00:00');
      expect(shift.isActive, isTrue);
      expect(shift.employeeCount, 25);
    });

    test('بيانات ناقصة/null', () {
      final json = {
        'id': 1.0,
        'tenant_id': 10.0,
      };

      final shift = ShiftModel.fromJson(json);

      expect(shift.id, 1);
      expect(shift.tenantId, 10);
      expect(shift.branchId, isNull);
      expect(shift.name, '');
      expect(shift.startTime, '');
      expect(shift.endTime, '');
      expect(shift.isActive, isFalse);
      expect(shift.employeeCount, 0);
    });

    test('is_active = 0 يعطي false', () {
      final shift = ShiftModel.fromJson({
        'id': 1,
        'tenant_id': 1,
        'is_active': 0,
      });

      expect(shift.isActive, isFalse);
    });

    test('toJson ينتج المفاتيح الصحيحة', () {
      final shift = ShiftModel.fromJson({
        'id': 1,
        'tenant_id': 10,
        'branch_id': 2,
        'name': 'صباحية',
        'start_time': '08:00',
        'end_time': '16:00',
        'is_active': 1,
      });

      final json = shift.toJson();

      expect(json['id'], 1);
      expect(json['tenant_id'], 10);
      expect(json['branch_id'], 2);
      expect(json['name'], 'صباحية');
      expect(json['start_time'], '08:00');
      expect(json['end_time'], '16:00');
      expect(json['is_active'], 1);
    });

    test('رحلة ذهاب وعودة', () {
      final original = ShiftModel.fromJson({
        'id': 1,
        'tenant_id': 10,
        'name': 'صباحية',
        'start_time': '08:00',
        'end_time': '16:00',
        'is_active': 1,
      });

      final json = original.toJson();
      final restored = ShiftModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.tenantId, original.tenantId);
      expect(restored.name, original.name);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
      expect(restored.isActive, original.isActive);
    });
  });
}
