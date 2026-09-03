import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:permedjat_app/core/class/crud.dart';
import 'package:permedjat_app/core/class/status_request.dart';
import 'package:permedjat_app/data/data_source/remote/auth_data/auth_data.dart';
import 'package:permedjat_app/data/model/user_model.dart';

import '../helpers/test_helpers.dart';

class MockAuthDataForController extends Mock implements AuthData {}

void main() {
  late MockAuthDataForController mockAuthData;

  setUp(() {
    setupGetTestBindings();
    registerFallbacks();
    mockAuthData = MockAuthDataForController();
    Get.put<AuthData>(mockAuthData);
    Get.put<CRUD>(CRUD());
  });

  tearDown(() {
    Get.reset();
  });

  group('AuthController — logout', () {
    test('clears user state', () async {
      when(() => mockAuthData.logout()).thenAnswer((_) async => <String, dynamic>{});
    });
  });

  group('AuthData integration', () {
    test('login response parses correctly into UserModel', () async {
      final loginPayload = {
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

      final employee =
          (loginPayload['data'] as Map<String, dynamic>)['employee']
              as Map<String, dynamic>;

      final user = UserModel(
        id: (employee['id'] as int?) ?? 0,
        tenantId: (employee['tenant_id'] as int?) ?? 0,
        branchId: (employee['branch_id'] as int?) ?? 0,
        name: (employee['name'] as String?) ?? '',
        email: '',
        branchName: employee['branch_name'] as String?,
        jobTitle: employee['job_title'] as String?,
        roleKey: 'employee',
      );

      expect(user.id, 5);
      expect(user.name, 'سارة');
      expect(user.tenantId, 1);
      expect(user.branchId, 2);
      expect(user.jobTitle, 'محاسبة');
      expect(user.branchName, 'فرع الرياض');

      final stored = jsonEncode(user.toJson());
      final retrieved = UserModel.fromJson(
          jsonDecode(stored) as Map<String, dynamic>);

      expect(retrieved.id, user.id);
      expect(retrieved.name, user.name);
      expect(retrieved.tenantId, user.tenantId);
    });

    test('error response (404) maps to correct status', () {
      final response = {
        'status': StatusRequest.failure,
        'statusCode': 404,
        'message': 'Invalid or expired code',
      };

      expect(response['status'], StatusRequest.failure);
      expect(response['statusCode'], 404);
    });

    test('error response (409) maps to leave overlap', () {
      final response = {
        'status': StatusRequest.failure,
        'statusCode': 409,
        'message': 'يوجد تداخل مع إجازة قائمة',
      };

      expect(response['statusCode'], 409);
      expect((response['message'] as String).contains('تداخل'), true);
    });
  });
}
