import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/asset_custody_model.dart';

void main() {
  group('AssetCustodyModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'employee_id': 10,
        'employee_name': 'أحمد',
        'type': 'equipment',
        'name': 'لابتوب',
        'description': 'لابتوب شركة',
        'value': 5000.0,
        'currency': 'SAR',
        'serial_no': 'SN123',
        'quantity': 2,
        'assign_photo_url': 'https://example.com/photo.jpg',
        'return_photo_url': null,
        'status': 'assigned',
        'notes': 'ملاحظة',
        'return_note': null,
        'rejection_reason': null,
        'assigned_at': '2025-01-15T10:00:00Z',
        'returned_at': null,
      };

      final asset = AssetCustodyModel.fromJson(json);

      expect(asset.id, 1);
      expect(asset.employeeId, 10);
      expect(asset.employeeName, 'أحمد');
      expect(asset.type, 'equipment');
      expect(asset.name, 'لابتوب');
      expect(asset.description, 'لابتوب شركة');
      expect(asset.value, 5000.0);
      expect(asset.currency, 'SAR');
      expect(asset.serialNo, 'SN123');
      expect(asset.quantity, 2);
      expect(asset.assignPhotoUrl, 'https://example.com/photo.jpg');
      expect(asset.returnPhotoUrl, isNull);
      expect(asset.status, 'assigned');
      expect(asset.notes, 'ملاحظة');
      expect(asset.returnedAt, isNull);
    });

    test('بيانات ناقصة/null', () {
      final asset = AssetCustodyModel.fromJson({});

      expect(asset.id, 0);
      expect(asset.employeeId, 0);
      expect(asset.employeeName, isNull);
      expect(asset.type, 'equipment');
      expect(asset.name, '');
      expect(asset.description, isNull);
      expect(asset.value, isNull);
      expect(asset.currency, 'SAR');
      expect(asset.serialNo, isNull);
      expect(asset.quantity, 1);
      expect(asset.status, 'assigned');
    });

    test('قيمة value كنص', () {
      final asset = AssetCustodyModel.fromJson({'value': '1200.50'});
      expect(asset.value, 1200.50);
    });

    test('تاريخ assigned_at غير صالح يستخدم now', () {
      final asset = AssetCustodyModel.fromJson({'assigned_at': 'invalid'});
      expect(asset.assignedAt, isNotNull);
    });

    test('status return_requested', () {
      final asset = AssetCustodyModel.fromJson({'status': 'return_requested'});
      expect(asset.status, 'return_requested');
    });

    test('status returned', () {
      final asset = AssetCustodyModel.fromJson({
        'status': 'returned',
        'returned_at': '2025-06-01T12:00:00Z',
      });
      expect(asset.status, 'returned');
      expect(asset.returnedAt, isNotNull);
    });
  });
}
