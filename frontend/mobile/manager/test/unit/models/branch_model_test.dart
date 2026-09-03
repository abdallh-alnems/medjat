import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/branch_model.dart';

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
