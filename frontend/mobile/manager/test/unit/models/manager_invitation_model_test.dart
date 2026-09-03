import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/manager_invitation_model.dart';

void main() {
  group('ManagerInvitationModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'name': 'خالد',
        'email': 'khaled@test.com',
        'role': 'hr',
        'branch_id': 5,
        'branch_name': 'الفرع الغربي',
        'expires_at': '2099-12-31T23:59:59Z',
        'accepted_at': null,
        'cancelled_at': null,
        'created_at': '2025-01-01T10:00:00Z',
      };

      final inv = ManagerInvitationModel.fromJson(json);

      expect(inv.id, 1);
      expect(inv.name, 'خالد');
      expect(inv.email, 'khaled@test.com');
      expect(inv.role, 'hr');
      expect(inv.branchId, 5);
      expect(inv.branchName, 'الفرع الغربي');
      expect(inv.expiresAt, '2099-12-31T23:59:59Z');
      expect(inv.acceptedAt, isNull);
      expect(inv.cancelledAt, isNull);
      expect(inv.createdAt, '2025-01-01T10:00:00Z');
    });

    test('statusKey — pending', () {
      final inv = ManagerInvitationModel.fromJson({
        'id': 1,
        'expires_at': '2099-12-31T23:59:59Z',
        'created_at': '2025-01-01T00:00:00Z',
      });
      expect(inv.statusKey, 'pending');
    });

    test('statusKey — accepted', () {
      final inv = ManagerInvitationModel.fromJson({
        'id': 1,
        'expires_at': '2099-12-31T23:59:59Z',
        'accepted_at': '2025-06-01T10:00:00Z',
        'created_at': '2025-01-01T00:00:00Z',
      });
      expect(inv.statusKey, 'accepted');
    });

    test('statusKey — cancelled', () {
      final inv = ManagerInvitationModel.fromJson({
        'id': 1,
        'expires_at': '2099-12-31T23:59:59Z',
        'cancelled_at': '2025-05-01T10:00:00Z',
        'created_at': '2025-01-01T00:00:00Z',
      });
      expect(inv.statusKey, 'cancelled');
    });

    test('statusKey — expired', () {
      final inv = ManagerInvitationModel.fromJson({
        'id': 1,
        'expires_at': '2020-01-01T00:00:00Z',
        'created_at': '2019-01-01T00:00:00Z',
      });
      expect(inv.statusKey, 'expired');
    });
  });

  group('AdminModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 2,
        'name': 'سارة',
        'email': 'sara@test.com',
        'phone': '0501234567',
        'role': 'manager',
        'branch_id': 3,
        'branch_name': 'الفرع الشمالي',
        'is_active': 1,
        'last_login_at': '2025-06-01T08:00:00Z',
      };

      final admin = AdminModel.fromJson(json);

      expect(admin.id, 2);
      expect(admin.name, 'سارة');
      expect(admin.email, 'sara@test.com');
      expect(admin.phone, '0501234567');
      expect(admin.role, 'manager');
      expect(admin.branchId, 3);
      expect(admin.isActive, isTrue);
      expect(admin.lastLoginAt, '2025-06-01T08:00:00Z');
    });

    test('بيانات ناقصة', () {
      final admin = AdminModel.fromJson({'id': 1});

      expect(admin.name, '');
      expect(admin.email, '');
      expect(admin.role, 'viewer');
      expect(admin.isActive, isFalse);
    });
  });
}
