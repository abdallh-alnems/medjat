import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/station_settings_model.dart';

void main() {
  group('StationSettingsModel.fromJson', () {
    test('بيانات كاملة - مفعلة', () {
      final json = {
        'station_enabled': 1,
        'station_methods': 'face_fingerprint',
        'station_gps_radius_meters': 50,
        'station_confidence_threshold': 0.95,
        'station_anti_spoofing_enabled': 1,
        'station_admin_pin_hash': 'abc123hash',
      };

      final settings = StationSettingsModel.fromJson(json);

      expect(settings.enabled, isTrue);
      expect(settings.methods, 'face_fingerprint');
      expect(settings.gpsRadiusMeters, 50);
      expect(settings.confidenceThreshold, 0.95);
      expect(settings.antiSpoofing, isTrue);
      expect(settings.hasAdminPin, isTrue);
    });

    test('بيانات ناقصة تعطي القيم الافتراضية', () {
      final settings = StationSettingsModel.fromJson({});

      expect(settings.enabled, isFalse);
      expect(settings.methods, 'face_only');
      expect(settings.gpsRadiusMeters, 30);
      expect(settings.confidenceThreshold, 0.85);
      expect(settings.antiSpoofing, isFalse);
      expect(settings.hasAdminPin, isFalse);
    });

    test('station_enabled = 0 يعطي false', () {
      final settings = StationSettingsModel.fromJson({'station_enabled': 0});
      expect(settings.enabled, isFalse);
    });

    test('station_admin_pin_hash = null يعطي hasAdminPin = false', () {
      final settings = StationSettingsModel.fromJson({'station_admin_pin_hash': null});
      expect(settings.hasAdminPin, isFalse);
    });
  });
}
