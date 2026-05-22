import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_central/data/model/role_model.dart';

void main() {
  group('RoleModel.fromJson', () {
    test('بيانات كاملة', () {
      final json = {
        'id': 1,
        'name': 'مدير فرع',
        'key': 'branch_manager',
        'scope': 'branch',
        'permissions': ['manage_employees', 'manage_attendance'],
        'branch_id': 2,
        'branch_name': 'الفرع الرئيسي',
      };

      final role = RoleModel.fromJson(json);

      expect(role.id, 1);
      expect(role.name, 'مدير فرع');
      expect(role.key, 'branch_manager');
      expect(role.scope, 'branch');
      expect(role.permissions, ['manage_employees', 'manage_attendance']);
      expect(role.branchId, 2);
      expect(role.branchName, 'الفرع الرئيسي');
    });

    test('بيانات ناقصة/null', () {
      final role = RoleModel.fromJson({});

      expect(role.id, 0);
      expect(role.name, '');
      expect(role.key, '');
      expect(role.scope, 'all');
      expect(role.permissions, isEmpty);
      expect(role.branchId, isNull);
      expect(role.branchName, isNull);
    });

    test('toJson ينتج snake_case صحيح', () {
      final role = RoleModel.fromJson({
        'id': 1,
        'name': 'مدير',
        'key': 'admin',
        'scope': 'branch',
        'permissions': ['read'],
        'branch_id': 2,
      });

      final json = role.toJson();

      expect(json['name'], 'مدير');
      expect(json['scope'], 'branch');
      expect(json['permissions'], ['read']);
      expect(json['branch_id'], 2);
      expect(json.containsKey('id'), isFalse);
    });

    test('toJson بدون branch_id لا يحتوي المفتاح', () {
      final role = RoleModel.fromJson({
        'name': 'مدير',
        'key': 'admin',
      });

      final json = role.toJson();
      expect(json.containsKey('branch_id'), isFalse);
    });

    test('رحلة ذهاب وعودة', () {
      final original = RoleModel.fromJson({
        'id': 1,
        'name': 'مدير',
        'key': 'admin',
        'scope': 'all',
        'permissions': ['read', 'write'],
        'branch_id': 5,
      });

      final json = original.toJson();
      final restored = RoleModel.fromJson({
        ...json,
        'id': 1,
        'key': 'admin',
      });

      expect(restored.name, original.name);
      expect(restored.scope, original.scope);
      expect(restored.permissions, original.permissions);
      expect(restored.branchId, original.branchId);
    });
  });
}
