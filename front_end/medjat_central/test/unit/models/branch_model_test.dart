import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/branch_model.dart';

void main() {
  group('BranchModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'name': 'الفرع الرئيسي',
        'address': 'الرياض - حي العليا',
        'lat': 24.7136,
        'lng': 46.6753,
        'qr_code': 'QR123',
        'employee_count': 50,
        'attendance_methods': ['gps', 'qr'],
        'gps_radius_meters': 200,
        'station_enabled': 1,
        'station_methods': 'face_only',
        'station_gps_radius_meters': 50,
        'station_confidence_threshold': 0.9,
        'station_anti_spoofing_enabled': 1,
        'station_admin_pin_hash': 'hash123',
        'allow_offline_attendance': true,
      };

      final branch = BranchModel.fromJson(json);

      expect(branch.id, 1);
      expect(branch.name, 'الفرع الرئيسي');
      expect(branch.address, 'الرياض - حي العليا');
      expect(branch.lat, 24.7136);
      expect(branch.lng, 46.6753);
      expect(branch.qrCode, 'QR123');
      expect(branch.employeeCount, 50);
      expect(branch.attendanceMethods, ['gps', 'qr']);
      expect(branch.gpsRadiusMeters, 200);
      expect(branch.stationEnabled, isTrue);
      expect(branch.stationMethods, 'face_only');
      expect(branch.stationGpsRadiusMeters, 50);
      expect(branch.stationConfidenceThreshold, 0.9);
      expect(branch.stationAntiSpoofing, isTrue);
      expect(branch.hasStationPin, isTrue);
      expect(branch.allowOfflineAttendance, isTrue);
    });

    test('بيانات ناقصة/null', () {
      final branch = BranchModel.fromJson({});

      expect(branch.id, 0);
      expect(branch.name, '');
      expect(branch.address, isNull);
      expect(branch.lat, isNull);
      expect(branch.lng, isNull);
      expect(branch.employeeCount, 0);
      expect(branch.attendanceMethods, isNull);
      expect(branch.gpsRadiusMeters, 100);
      expect(branch.stationEnabled, isFalse);
      expect(branch.stationMethods, 'face_only');
      expect(branch.stationGpsRadiusMeters, 30);
      expect(branch.stationConfidenceThreshold, 0.85);
      expect(branch.stationAntiSpoofing, isFalse);
      expect(branch.hasStationPin, isFalse);
      expect(branch.allowOfflineAttendance, isNull);
    });

    test('allow_offline_attendance كعدد صحيح', () {
      final branch = BranchModel.fromJson({
        'allow_offline_attendance': 1,
      });
      expect(branch.allowOfflineAttendance, isTrue);
    });

    test('allow_offline_attendance = 0', () {
      final branch = BranchModel.fromJson({
        'allow_offline_attendance': 0,
      });
      expect(branch.allowOfflineAttendance, isFalse);
    });

    test('station_enabled = 0 يعطي false', () {
      final branch = BranchModel.fromJson({
        'station_enabled': 0,
      });
      expect(branch.stationEnabled, isFalse);
    });

    test('copyWith يحافظ على القيم', () {
      final original = BranchModel.fromJson({
        'id': 1,
        'name': 'الفرع الرئيسي',
        'address': 'الرياض',
      });
      final copy = original.copyWith(name: 'الفرع الجديد');

      expect(copy.id, 1);
      expect(copy.name, 'الفرع الجديد');
      expect(copy.address, 'الرياض');
    });
  });
}
