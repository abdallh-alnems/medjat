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

    test('fromJson with nested branch object', () {
      final json = {
        'date': '2026-05-21',
        'check_in_time': '08:00:00',
        'branch': {
          'id': 10,
          'name': 'فرع المدينة',
          'latitude': 24.5,
          'longitude': 47.5,
          'gps_radius_meters': 150,
        },
      };
      final model = TodayStatusModel.fromJson(json);

      expect(model.branchId, 10);
      expect(model.branchName, 'فرع المدينة');
      expect(model.branchLat, 24.5);
      expect(model.branchLng, 47.5);
      expect(model.branchRadiusMeters, 150);
    });

    test('fromJson with check_in_at/check_out_at aliases', () {
      final json = {
        'date': '2026-05-21',
        'check_in_at': '2026-05-21T08:30:00.000',
        'check_out_at': '2026-05-21T17:00:00.000',
      };
      final model = TodayStatusModel.fromJson(json);

      expect(model.status, AttendanceStatus.checkedOut);
      expect(model.checkInAt, isNotNull);
      expect(model.checkOutAt, isNotNull);
    });

    test('fromJson with empty json defaults', () {
      final model = TodayStatusModel.fromJson({});

      expect(model.status, AttendanceStatus.notCheckedIn);
      expect(model.isLate, false);
      expect(model.lateMinutes, 0);
      expect(model.branchId, isNull);
      expect(model.branchName, isNull);
      expect(model.branchLat, isNull);
      expect(model.branchLng, isNull);
      expect(model.branchRadiusMeters, isNull);
    });

    test('fromJson is_late as integer 1', () {
      final json = {
        'is_late': 1,
        'late_minutes': 30,
      };
      final model = TodayStatusModel.fromJson(json);

      expect(model.isLate, true);
      expect(model.lateMinutes, 30);
    });

    test('fromJson is_late as integer 0', () {
      final json = {
        'is_late': 0,
      };
      final model = TodayStatusModel.fromJson(json);

      expect(model.isLate, false);
    });

    test('fromJson with check_in_latitude/longitude', () {
      final json = {
        'date': '2026-05-21',
        'check_in_time': '08:00:00',
        'check_in_latitude': 24.7136,
        'check_in_longitude': 46.6753,
      };
      final model = TodayStatusModel.fromJson(json);

      expect(model.checkInLat, 24.7136);
      expect(model.checkInLng, 46.6753);
    });

    test('fromJson with check_in_lat/check_in_lng aliases', () {
      final json = {
        'check_in_lat': 25.0,
        'check_in_lng': 47.0,
      };
      final model = TodayStatusModel.fromJson(json);

      expect(model.checkInLat, 25.0);
      expect(model.checkInLng, 47.0);
    });

    test('toJson includes check times as ISO strings', () {
      final checkIn = DateTime(2026, 5, 21, 8, 30);
      final checkOut = DateTime(2026, 5, 21, 17);
      final model = TodayStatusModel(
        status: AttendanceStatus.checkedOut,
        checkInAt: checkIn,
        checkOutAt: checkOut,
        isLate: true,
        lateMinutes: 15,
      );
      final json = model.toJson();

      expect(json['check_in_at'], checkIn.toIso8601String());
      expect(json['check_out_at'], checkOut.toIso8601String());
      expect(json['is_late'], true);
      expect(json['late_minutes'], 15);
    });

    test('toJson with null check times', () {
      final model = TodayStatusModel(
        status: AttendanceStatus.notCheckedIn,
      );
      final json = model.toJson();

      expect(json['check_in_at'], isNull);
      expect(json['check_out_at'], isNull);
    });

    test('AttendanceStatus enum values', () {
      expect(AttendanceStatus.values.length, 3);
      expect(AttendanceStatus.values,
          contains(AttendanceStatus.notCheckedIn));
      expect(AttendanceStatus.values, contains(AttendanceStatus.checkedIn));
      expect(AttendanceStatus.values, contains(AttendanceStatus.checkedOut));
    });
  });
}
