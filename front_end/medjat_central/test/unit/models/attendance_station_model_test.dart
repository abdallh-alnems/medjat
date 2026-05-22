import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/attendance_station_model.dart';

void main() {
  group('AttendanceStationModel.fromJson', () {
    test('بيانات كاملة - محطة مفعلة', () {
      final json = {
        'id': 1,
        'branch_id': 5,
        'branch_name': 'الفرع الرئيسي',
        'device_name': 'جهاز 1',
        'device_token': 'token123',
        'is_activated': 1,
        'is_active': 1,
        'is_locked': 0,
        'locked_reason': null,
        'activated_at': '2025-01-01T08:00:00Z',
        'last_heartbeat_at': '2025-06-01T09:00:00Z',
        'last_known_lat': 24.7136,
        'last_known_lng': 46.6753,
        'activation_qr_payload': 'qr123',
        'activation_qr_expires_at': '2025-12-31T23:59:59Z',
      };

      final station = AttendanceStationModel.fromJson(json);

      expect(station.id, 1);
      expect(station.branchId, 5);
      expect(station.branchName, 'الفرع الرئيسي');
      expect(station.deviceName, 'جهاز 1');
      expect(station.deviceToken, 'token123');
      expect(station.isActivated, isTrue);
      expect(station.isActive, isTrue);
      expect(station.isLocked, isFalse);
      expect(station.lockedReason, isNull);
      expect(station.activatedAt, isNotNull);
      expect(station.lastHeartbeatAt, isNotNull);
      expect(station.lastKnownLat, 24.7136);
      expect(station.lastKnownLng, 46.6753);
      expect(station.qrPayload, 'qr123');
      expect(station.qrExpiresAt, isNotNull);
    });

    test('بيانات ناقصة/null', () {
      final station = AttendanceStationModel.fromJson({});

      expect(station.id, 0);
      expect(station.branchId, 0);
      expect(station.branchName, '');
      expect(station.deviceName, '');
      expect(station.deviceToken, '');
      expect(station.isActivated, isFalse);
      expect(station.isActive, isFalse);
      expect(station.isLocked, isFalse);
      expect(station.lockedReason, isNull);
      expect(station.activatedAt, isNull);
      expect(station.lastHeartbeatAt, isNull);
      expect(station.lastKnownLat, isNull);
      expect(station.lastKnownLng, isNull);
      expect(station.qrPayload, isNull);
      expect(station.qrExpiresAt, isNull);
    });

    test('statusLabel — locked', () {
      final station = AttendanceStationModel.fromJson({
        'is_locked': 1,
        'is_active': 1,
        'is_activated': 1,
      });
      expect(station.statusLabel, 'locked');
    });

    test('statusLabel — deactivated', () {
      final station = AttendanceStationModel.fromJson({
        'is_locked': 0,
        'is_active': 0,
        'is_activated': 1,
      });
      expect(station.statusLabel, 'deactivated');
    });

    test('statusLabel — pending', () {
      final station = AttendanceStationModel.fromJson({
        'is_locked': 0,
        'is_active': 1,
        'is_activated': 0,
      });
      expect(station.statusLabel, 'pending');
    });

    test('statusLabel — active', () {
      final station = AttendanceStationModel.fromJson({
        'is_locked': 0,
        'is_active': 1,
        'is_activated': 1,
      });
      expect(station.statusLabel, 'active');
    });
  });
}
