import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_app/data/model/today_status_model.dart';

void main() {
  group('TodayStatusModel', () {
    test('fromJson with check_in_time only → checkedIn', () {
      final json = {
        'date': '2026-05-21',
        'check_in_time': '08:30:00',
        'branch_id': 1,
        'branch_name': 'الفرع',
      };
      final model = TodayStatusModel.fromJson(json);

      expect(model.status, AttendanceStatus.checkedIn);
      expect(model.checkInAt, isNotNull);
      expect(model.checkOutAt, isNull);
      expect(model.branchId, 1);
      expect(model.branchName, 'الفرع');
    });

    test('fromJson with both times → checkedOut', () {
      final json = {
        'date': '2026-05-21',
        'check_in_time': '08:30:00',
        'check_out_time': '17:00:00',
      };
      final model = TodayStatusModel.fromJson(json);

      expect(model.status, AttendanceStatus.checkedOut);
      expect(model.checkInAt, isNotNull);
      expect(model.checkOutAt, isNotNull);
    });

    test('fromJson with no times → notCheckedIn', () {
      final model = TodayStatusModel.fromJson({'date': '2026-05-21'});

      expect(model.status, AttendanceStatus.notCheckedIn);
      expect(model.checkInAt, isNull);
      expect(model.checkOutAt, isNull);
    });

    test('fromJson detects late arrival', () {
      final json = {
        'date': '2026-05-21',
        'check_in_time': '09:45:00',
        'is_late': true,
        'late_minutes': 45,
      };
      final model = TodayStatusModel.fromJson(json);

      expect(model.isLate, true);
      expect(model.lateMinutes, 45);
    });

    test('fromJson handles ISO8601 datetime strings', () {
      final json = {
        'check_in_at': '2026-05-21T08:30:00.000',
        'check_out_at': '2026-05-21T17:00:00.000',
      };
      final model = TodayStatusModel.fromJson(json);

      expect(model.status, AttendanceStatus.checkedOut);
    });

    test('fromJson extracts branch data', () {
      final json = {
        'date': '2026-05-21',
        'branch_id': 5,
        'branch_name': 'فرع جدة',
        'branch_lat': 21.5,
        'branch_lng': 39.2,
        'branch_radius_meters': 200,
      };
      final model = TodayStatusModel.fromJson(json);

      expect(model.branchId, 5);
      expect(model.branchName, 'فرع جدة');
      expect(model.branchLat, 21.5);
      expect(model.branchLng, 39.2);
      expect(model.branchRadiusMeters, 200);
    });

    test('toJson produces valid map', () {
      final model = TodayStatusModel(
        status: AttendanceStatus.checkedIn,
        branchId: 1,
        branchName: 'الفرع',
      );
      final json = model.toJson();

      expect(json['branch_id'], 1);
      expect(json['branch_name'], 'الفرع');
    });
  });
}
