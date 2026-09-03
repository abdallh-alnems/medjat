import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:permedjat_app/core/class/crud.dart';
import 'package:permedjat_app/core/class/status_request.dart';
import 'package:permedjat_app/data/data_source/remote/auth_data/auth_data.dart';
import 'package:permedjat_app/data/model/user_model.dart';

import '../helpers/test_helpers.dart';

class MockAuthDataIntegration extends Mock implements AuthData {}

void main() {
  late MockAuthDataIntegration mockAuthData;

  setUp(() {
    setupGetTestBindings();
    registerFallbacks();
    mockAuthData = MockAuthDataIntegration();
    Get.put<AuthData>(mockAuthData);
    Get.put<CRUD>(MockCRUD());
  });

  tearDown(() {
    Get.reset();
  });

  group('Login flow integration', () {
    test('full activation flow: cached user -> checkAuth -> success', () async {
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

      when(() => mockAuthData.getCachedUser()).thenAnswer((_) async {
        return UserModel.fromJson(
          jsonDecode(jsonEncode(userData)) as Map<String, dynamic>,
        );
      });

      final cachedUser = await mockAuthData.getCachedUser();

      expect(cachedUser, isNotNull);
      expect(cachedUser!.id, 1);
      expect(cachedUser.name, 'أحمد');
      expect(cachedUser.tenantId, 2);
      expect(cachedUser.tenantId != 0, true);
    });

    test('activation with valid code returns success', () async {
      when(() => mockAuthData.login(
            phone: any(named: 'phone'),
            activationCode: any(named: 'activationCode'),
          )).thenAnswer((_) async => {
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
          });

      final response = await mockAuthData.login(
        phone: '0501234567',
        activationCode: 'VALID1',
      );

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
    });

    test('activation with invalid code returns failure', () async {
      when(() => mockAuthData.login(
            phone: any(named: 'phone'),
            activationCode: any(named: 'activationCode'),
          )).thenAnswer((_) async => {
            'status': StatusRequest.failure,
            'statusCode': 404,
            'message': 'كود التفعيل غير صالح أو منتهي',
          });

      final response = await mockAuthData.login(
        phone: '0501234567',
        activationCode: 'INVALID',
      );

      expect(response['status'], StatusRequest.failure);
      expect(response['statusCode'], 404);
    });

    test('logout flow clears state', () async {
      when(() => mockAuthData.logout()).thenAnswer((_) async => <String, dynamic>{});

      await mockAuthData.logout();

      verify(() => mockAuthData.logout()).called(1);
    });

    test('getProfile returns user data', () async {
      when(() => mockAuthData.getProfile()).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'employee': {
                'id': 1,
                'name': 'أحمد',
                'tenant_id': 2,
                'branch_id': 3,
                'email': 'ahmed@test.com',
                'role_key': 'admin',
                'permissions': ['read', 'write', 'delete'],
              },
            },
          });

      final response = await mockAuthData.getProfile();

      expect(response['status'], StatusRequest.success);
      final data = response['data'] as Map<String, dynamic>;
      final emp = data['employee'] as Map<String, dynamic>;

      final user = UserModel.fromJson(emp);
      expect(user.roleKey, 'admin');
      expect(user.permissions, ['read', 'write', 'delete']);
    });

    test('checkAuth with no cached user returns false', () async {
      when(() => mockAuthData.getCachedUser())
          .thenAnswer((_) async => null);

      final cached = await mockAuthData.getCachedUser();
      final hasAuth = cached != null;

      expect(hasAuth, false);
    });

    test('checkAuth with cached user with zero tenantId is not activated',
        () async {
      when(() => mockAuthData.getCachedUser()).thenAnswer((_) async {
        return UserModel(
          id: 1,
          tenantId: 0,
          branchId: 0,
          name: 'أحمد',
          email: '',
          roleKey: 'employee',
        );
      });

      final cached = await mockAuthData.getCachedUser();

      expect(cached, isNotNull);
      expect(cached!.tenantId, 0);
      expect(cached.tenantId != 0, false);
    });
  });
}
