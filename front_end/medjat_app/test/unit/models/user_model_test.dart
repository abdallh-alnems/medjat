import 'package:flutter_test/flutter_test.dart';
import 'package:medjat_app/data/model/user_model.dart';

void main() {
  group('UserModel', () {
    final json = {
      'id': 1,
      'tenant_id': 2,
      'tenant_name': 'شركة الاختبار',
      'branch_id': 3,
      'name': 'أحمد',
      'email': 'ahmed@test.com',
      'phone': '0501234567',
      'photo_url': 'https://example.com/photo.jpg',
      'role_key': 'employee',
      'permissions': ['read', 'write'],
      'employee_code': 'EMP001',
      'job_title': 'مهندس',
      'branch_name': 'الفرع الرئيسي',
    };

    test('fromJson creates correct model', () {
      final user = UserModel.fromJson(json);

      expect(user.id, 1);
      expect(user.tenantId, 2);
      expect(user.tenantName, 'شركة الاختبار');
      expect(user.branchId, 3);
      expect(user.name, 'أحمد');
      expect(user.email, 'ahmed@test.com');
      expect(user.phone, '0501234567');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.roleKey, 'employee');
      expect(user.permissions, <String>['read', 'write']);
      expect(user.employeeCode, 'EMP001');
      expect(user.jobTitle, 'مهندس');
      expect(user.branchName, 'الفرع الرئيسي');
    });

    test('fromJson handles missing fields with defaults', () {
      final user = UserModel.fromJson({});

      expect(user.id, 0);
      expect(user.tenantId, 0);
      expect(user.branchId, 0);
      expect(user.name, '');
      expect(user.email, '');
      expect(user.phone, isNull);
      expect(user.photoUrl, isNull);
      expect(user.roleKey, '');
      expect(user.permissions, <String>[]);
      expect(user.employeeCode, isNull);
      expect(user.jobTitle, isNull);
      expect(user.branchName, isNull);
    });

    test('toJson produces correct map', () {
      final user = UserModel.fromJson(json);
      final result = user.toJson();

      expect(result['id'], 1);
      expect(result['tenant_id'], 2);
      expect(result['name'], 'أحمد');
      expect(result['email'], 'ahmed@test.com');
      expect(result['permissions'], ['read', 'write']);
    });

    test('round-trip preserves data', () {
      final original = UserModel.fromJson(json);
      final roundTripped = UserModel.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.name, original.name);
      expect(roundTripped.email, original.email);
      expect(roundTripped.tenantId, original.tenantId);
      expect(roundTripped.branchId, original.branchId);
    });

    test('fromJson with null integer fields defaults to 0', () {
      final user = UserModel.fromJson({
        'id': null,
        'tenant_id': null,
        'branch_id': null,
      });

      expect(user.id, 0);
      expect(user.tenantId, 0);
      expect(user.branchId, 0);
    });

    test('fromJson with wrong int type throws cast error', () {
      expect(
        () => UserModel.fromJson({'id': 'not a number'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('toJson includes all fields with null values', () {
      final user = UserModel(
        id: 1,
        tenantId: 0,
        branchId: 0,
        name: 'test',
        email: 'test@test.com',
        roleKey: 'emp',
      );

      final result = user.toJson();

      expect(result['phone'], isNull);
      expect(result['photo_url'], isNull);
      expect(result['tenant_name'], isNull);
      expect(result['employee_code'], isNull);
      expect(result['job_title'], isNull);
      expect(result['branch_name'], isNull);
      expect(result['permissions'], []);
    });

    test('fromJson handles permissions with mixed types', () {
      final user = UserModel.fromJson({
        'permissions': [1, 'admin', true],
      });

      expect(user.permissions, ['1', 'admin', 'true']);
    });

    test('fromJson with empty permissions list', () {
      final user = UserModel.fromJson({'permissions': []});

      expect(user.permissions, isEmpty);
    });

    test('toJson round-trip preserves permissions', () {
      final user = UserModel.fromJson(json);
      final roundTripped = UserModel.fromJson(user.toJson());

      expect(roundTripped.permissions, user.permissions);
    });

    test('constructor defaults work correctly', () {
      final user = UserModel(
        id: 5,
        tenantId: 1,
        branchId: 2,
        name: 'خالد',
        email: 'khaled@test.com',
        roleKey: 'admin',
      );

      expect(user.permissions, isEmpty);
      expect(user.phone, isNull);
      expect(user.photoUrl, isNull);
      expect(user.employeeCode, isNull);
      expect(user.jobTitle, isNull);
      expect(user.branchName, isNull);
      expect(user.tenantName, isNull);
    });

    test('equality by value (same data)', () {
      final user1 = UserModel.fromJson(json);
      final user2 = UserModel.fromJson(json);

      expect(user1.id, user2.id);
      expect(user1.name, user2.name);
      expect(user1.email, user2.email);
    });
  });
}
