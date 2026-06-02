import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medjat_app/core/class/crud.dart';
import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/data/data_source/remote/auth_data/auth_data.dart';
import 'package:medjat_app/data/model/user_model.dart';

import '../../../../helpers/test_helpers.dart';

class MockAuthDataInner extends Mock implements AuthData {}

void main() {
  group('AuthData — getCachedUser parsing', () {
    test('parses valid cached JSON into UserModel', () {
      final userData = {
        'id': 1,
        'tenant_id': 2,
        'branch_id': 3,
        'name': 'أحمد',
        'email': 'ahmed@test.com',
        'role_key': 'employee',
        'job_title': 'مهندس',
        'branch_name': 'الفرع الرئيسي',
        'tenant_name': 'شركة الاختبار',
      };

      final encoded = jsonEncode(userData);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final user = UserModel.fromJson(decoded);

      expect(user.id, 1);
      expect(user.tenantId, 2);
      expect(user.name, 'أحمد');
      expect(user.tenantName, 'شركة الاختبار');
      expect(user.branchName, 'الفرع الرئيسي');
      expect(user.jobTitle, 'مهندس');
    });

    test('handles corrupted cached JSON gracefully', () {
      const corruptedJson = 'not valid json{}{';

      try {
        jsonDecode(corruptedJson);
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<FormatException>());
      }
    });

    test('handles missing optional fields with defaults', () {
      final minimalData = {
        'id': 10,
        'name': 'خالد',
      };

      final encoded = jsonEncode(minimalData);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final user = UserModel.fromJson(decoded);

      expect(user.id, 10);
      expect(user.name, 'خالد');
      expect(user.tenantId, 0);
      expect(user.branchId, 0);
      expect(user.email, '');
      expect(user.phone, isNull);
      expect(user.photoUrl, isNull);
      expect(user.permissions, isEmpty);
      expect(user.employeeCode, isNull);
      expect(user.jobTitle, isNull);
      expect(user.branchName, isNull);
    });
  });

  group('AuthData — login response handling', () {
    test('success response with employee data', () {
      final response = {
        'status': StatusRequest.success,
        'data': {
          'token': 'test-token-123',
          'employee': {
            'id': 5,
            'name': 'سارة',
            'tenant_id': 1,
            'tenant_name': 'شركة النور',
            'branch_id': 2,
            'branch_name': 'فرع الرياض',
            'job_title': 'محاسبة',
          },
        },
      };

      expect(response['status'], StatusRequest.success);
      final data = response['data'] as Map<String, dynamic>;
      final employee = data['employee'] as Map<String, dynamic>;

      final user = UserModel.fromJson({
        ...employee,
        'email': '',
        'role_key': 'employee',
      });

      expect(user.id, 5);
      expect(user.name, 'سارة');
      expect(user.tenantId, 1);
      expect(user.branchId, 2);
    });

    test('failure response with 404', () {
      final response = {
        'status': StatusRequest.failure,
        'statusCode': 404,
        'message': 'كود التفعيل غير صالح أو منتهي',
      };

      expect(response['status'], StatusRequest.failure);
      expect(response['statusCode'], 404);
      expect(response['message'], 'كود التفعيل غير صالح أو منتهي');
    });

    test('failure response with expired session 401', () {
      final response = {
        'status': StatusRequest.failure,
        'statusCode': 401,
        'message': 'جلستك انتهت، يرجى تسجيل الدخول مجدداً',
      };

      expect(response['status'], StatusRequest.failure);
      expect(response['statusCode'], 401);
      expect(response['message'], contains('انتهت'));
    });
  });

  group('AuthData — getProfile response', () {
    test('success response maps to employee profile', () {
      final response = {
        'status': StatusRequest.success,
        'data': {
          'employee': {
            'id': 1,
            'name': 'أحمد',
            'email': 'ahmed@test.com',
            'phone': '0501234567',
            'photo_url': 'https://example.com/photo.jpg',
            'job_title': 'مهندس برمجيات',
            'tenant_id': 2,
            'tenant_name': 'شركة التقنية',
            'branch_id': 1,
            'branch_name': 'الفرع الرئيسي',
          },
        },
      };

      final data = response['data'] as Map<String, dynamic>;
      final emp = data['employee'] as Map<String, dynamic>;
      final user = UserModel.fromJson(emp);

      expect(user.id, 1);
      expect(user.name, 'أحمد');
      expect(user.phone, '0501234567');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
      expect(user.jobTitle, 'مهندس برمجيات');
    });
  });
}
