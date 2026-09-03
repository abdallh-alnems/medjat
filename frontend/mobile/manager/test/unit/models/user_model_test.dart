import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_central/data/model/user_model.dart';

void main() {
  group('UserModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'tenant_id': 10,
        'branch_id': 2,
        'name': 'مدير النظام',
        'email': 'admin@example.com',
        'phone': '0501234567',
        'photo_url': 'https://example.com/photo.jpg',
        'role_key': 'owner',
        'permissions': ['manage_employees', 'manage_payroll'],
        'employee_code': 'ADM001',
        'job_title': 'مدير',
        'branch_name': 'الفرع الرئيسي',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 1);
      expect(user.tenantId, 10);
      expect(user.branchId, 2);
      expect(user.name, 'مدير النظام');
      expect(user.email, 'admin@example.com');
      expect(user.phone, '0501234567');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.roleKey, 'owner');
      expect(user.permissions, ['manage_employees', 'manage_payroll']);
      expect(user.employeeCode, 'ADM001');
      expect(user.jobTitle, 'مدير');
      expect(user.branchName, 'الفرع الرئيسي');
    });

    test('بيانات ناقصة/null', () {
      final user = UserModel.fromJson({});

      expect(user.id, 0);
      expect(user.tenantId, 0);
      expect(user.branchId, 0);
      expect(user.name, '');
      expect(user.email, '');
      expect(user.roleKey, '');
      expect(user.permissions, isEmpty);
    });

    test('isGeneralManager', () {
      expect(UserModel.fromJson({'role_key': 'general_manager'}).isGeneralManager,
          isTrue);
      // There is no longer an "owner" role — only general_manager is the top role.
      expect(UserModel.fromJson({'role_key': 'owner'}).isGeneralManager, isFalse);
      expect(UserModel.fromJson({'role_key': 'hr'}).isGeneralManager, isFalse);
    });

    test('isHR', () {
      expect(UserModel.fromJson({'role_key': 'hr'}).isHR, isTrue);
      expect(UserModel.fromJson({'role_key': 'owner'}).isHR, isFalse);
    });

    test('isManager', () {
      expect(UserModel.fromJson({'role_key': 'branch_manager'}).isManager, isTrue);
    });

    test('canManageEmployees', () {
      expect(UserModel.fromJson({'role_key': 'general_manager'}).canManageEmployees, isTrue);
      expect(UserModel.fromJson({'role_key': 'hr'}).canManageEmployees, isTrue);
      expect(UserModel.fromJson({'role_key': 'employee', 'permissions': ['manage_employees']}).canManageEmployees, isTrue);
      expect(UserModel.fromJson({'role_key': 'employee'}).canManageEmployees, isFalse);
    });

    test('canManagePayroll', () {
      expect(UserModel.fromJson({'role_key': 'general_manager'}).canManagePayroll, isTrue);
      expect(UserModel.fromJson({'role_key': 'hr'}).canManagePayroll, isTrue);
      expect(UserModel.fromJson({'role_key': 'employee'}).canManagePayroll, isFalse);
    });

    test('canManageBranches', () {
      expect(UserModel.fromJson({'role_key': 'general_manager'}).canManageBranches, isTrue);
      expect(UserModel.fromJson({'role_key': 'employee', 'permissions': ['manage_company_settings']}).canManageBranches, isTrue);
      expect(UserModel.fromJson({'role_key': 'hr'}).canManageBranches, isFalse);
    });

    test('toJson و fromJson رحلة ذهاب وعودة', () {
      final original = UserModel.fromJson({
        'id': 1,
        'tenant_id': 10,
        'branch_id': 2,
        'name': 'مدير',
        'email': 'admin@test.com',
        'role_key': 'owner',
        'permissions': ['read'],
      });

      final json = original.toJson();
      final restored = UserModel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.tenantId, original.tenantId);
      expect(restored.branchId, original.branchId);
      expect(restored.name, original.name);
      expect(restored.email, original.email);
      expect(restored.roleKey, original.roleKey);
      expect(restored.permissions, original.permissions);
    });
  });
}
