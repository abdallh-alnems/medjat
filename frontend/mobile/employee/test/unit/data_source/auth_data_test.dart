import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:permedjat_app/data/model/user_model.dart';

void main() {
  group('AuthData unit', () {
    test('UserModel fromJson parses activation response correctly', () {
      final activationResponse = {
        'id': 10,
        'name': 'سارة',
        'tenant_id': 5,
        'tenant_name': 'شركة النور',
        'branch_id': 3,
        'branch_name': 'فرع الرياض',
        'job_title': 'محاسبة',
        'email': 'sara@noor.com',
      };

      final user = UserModel.fromJson(activationResponse);

      expect(user.id, 10);
      expect(user.name, 'سارة');
      expect(user.tenantId, 5);
      expect(user.tenantName, 'شركة النور');
      expect(user.branchId, 3);
      expect(user.branchName, 'فرع الرياض');
      expect(user.jobTitle, 'محاسبة');
    });

    test('stored JSON round-trips through secure storage format', () {
      final userData = {
        'id': 1,
        'tenant_id': 2,
        'branch_id': 3,
        'name': 'خالد',
        'email': 'khaled@test.com',
        'role_key': 'employee',
      };

      final encoded = jsonEncode(userData);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final user = UserModel.fromJson(decoded);

      expect(user.id, 1);
      expect(user.tenantId, 2);
      expect(user.name, 'خالد');
    });
  });
}
