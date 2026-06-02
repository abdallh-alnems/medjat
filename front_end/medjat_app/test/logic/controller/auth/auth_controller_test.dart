import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:medjat_app/core/class/crud.dart';
import 'package:medjat_app/core/class/status_request.dart';
import 'package:medjat_app/data/data_source/remote/auth_data/auth_data.dart';
import 'package:medjat_app/data/model/user_model.dart';

import '../../../helpers/test_helpers.dart';

class MockAuthData extends Mock implements AuthData {}

void main() {
  late MockAuthData mockAuthData;

  setUp(() {
    setupGetTestBindings();
    registerFallbacks();
    mockAuthData = MockAuthData();
    Get.put<AuthData>(mockAuthData);
    Get.put<CRUD>(MockCRUD());
  });

  tearDown(() {
    Get.reset();
  });

  group('AuthController — checkAuth', () {
    test('checkAuth returns false when no cached user', () async {
      when(() => mockAuthData.getCachedUser())
          .thenAnswer((_) async => null);

      final controller = Get.put<TestableAuthController>(
        TestableAuthController(),
      );

      final result = await controller.checkAuth();

      expect(result, false);
      expect(controller.isLoggedInObs.value, false);
    });

    test('checkAuth returns true with cached user', () async {
      when(() => mockAuthData.getCachedUser())
          .thenAnswer((_) async => createTestUser());

      final controller = Get.put<TestableAuthController>(
        TestableAuthController(),
      );

      final result = await controller.checkAuth();

      expect(result, true);
      expect(controller.isLoggedInObs.value, true);
      expect(controller.user, isNotNull);
    });
  });

  group('AuthController — logout', () {
    test('logout clears state', () async {
      when(() => mockAuthData.logout()).thenAnswer((_) async => {});

      final controller = Get.put<TestableAuthController>(
        TestableAuthController(),
      );
      controller.isLoggedInObs.value = true;
      controller.user = createTestUser();

      await controller.logout();

      expect(controller.user, isNull);
      expect(controller.isLoggedInObs.value, false);
      verify(() => mockAuthData.logout()).called(1);
    });
  });

  group('AuthController — login', () {
    test('login success saves token and user', () async {
      when(() => mockAuthData.login(
            phone: any(named: 'phone'),
            activationCode: any(named: 'activationCode'),
          )).thenAnswer((_) async => {
            'status': StatusRequest.success,
            'data': {
              'token': 'test-token-123',
              'employee': {
                'id': 1,
                'name': 'أحمد',
                'tenant_id': 2,
                'tenant_name': 'شركة',
                'branch_id': 3,
                'branch_name': 'فرع',
                'job_title': 'مهندس',
                'phone': '0501234567',
                'profile_image': null,
              },
            },
          });
      when(() => mockAuthData.getCachedUser())
          .thenAnswer((_) async => UserModel.fromJson({
                'id': 1,
                'name': 'أحمد',
                'tenant_id': 2,
                'tenant_name': 'شركة',
                'branch_id': 3,
                'branch_name': 'فرع',
                'job_title': 'مهندس',
                'phone': '0501234567',
                'email': '',
                'role_key': 'employee',
              }));

      final controller = Get.put<TestableAuthController>(
        TestableAuthController(),
      );

      await controller.login(phone: '0501234567', code: 'AB23CD');

      expect(controller.status.value, StatusRequest.success);
      expect(controller.isLoggedInObs.value, true);
      expect(controller.user, isNotNull);
    });

    test('login 403 maps to phone mismatch message', () async {
      when(() => mockAuthData.login(
            phone: any(named: 'phone'),
            activationCode: any(named: 'activationCode'),
          )).thenAnswer((_) async => {
            'status': StatusRequest.failure,
            'statusCode': 403,
            'message': 'رقم الهاتف لا يطابق كود التفعيل',
          });

      final controller = Get.put<TestableAuthController>(
        TestableAuthController(),
      );

      await controller.login(phone: '0000000000', code: 'AB23CD');

      expect(controller.status.value, StatusRequest.failure);
    });

    test('login 404 maps to invalid code message', () async {
      when(() => mockAuthData.login(
            phone: any(named: 'phone'),
            activationCode: any(named: 'activationCode'),
          )).thenAnswer((_) async => {
            'status': StatusRequest.failure,
            'statusCode': 404,
            'message': 'كود التفعيل غير صالح أو منتهي',
          });

      final controller = Get.put<TestableAuthController>(
        TestableAuthController(),
      );

      await controller.login(phone: '0501234567', code: 'BADCOD');

      expect(controller.status.value, StatusRequest.failure);
    });
  });

  group('AuthController — data parsing', () {
    test('UserModel from login response round-trips', () {
      final userData = {
        'id': 5,
        'name': 'سارة',
        'tenant_id': 1,
        'tenant_name': 'شركة النور',
        'branch_id': 2,
        'branch_name': 'فرع الرياض',
        'job_title': 'محاسبة',
        'email': '',
        'role_key': 'employee',
      };

      final user = UserModel.fromJson(userData);
      final encoded = jsonEncode(user.toJson());
      final decoded = UserModel.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(decoded.id, 5);
      expect(decoded.name, 'سارة');
      expect(decoded.tenantId, 1);
      expect(decoded.branchId, 2);
      expect(decoded.jobTitle, 'محاسبة');
      expect(decoded.branchName, 'فرع الرياض');
    });
  });
}

class TestableAuthController extends GetxController {
  final AuthData _authData = Get.find<AuthData>();

  final status = StatusRequest.none.obs;
  final isLoggedInObs = false.obs;
  UserModel? user;

  @override
  void onInit() {
    super.onInit();
  }

  Future<bool> checkAuth() async {
    final cached = await _authData.getCachedUser();
    if (cached != null) {
      user = cached;
      isLoggedInObs.value = true;
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _authData.logout();
    user = null;
    isLoggedInObs.value = false;
  }

  Future<void> login({
    required String phone,
    required String code,
  }) async {
    status.value = StatusRequest.loading;

    try {
      final response = await _authData.login(
        phone: phone.trim(),
        activationCode: code.trim(),
      );

      if (response['status'] == StatusRequest.success) {
        final cached = await _authData.getCachedUser();
        if (cached != null) {
          user = cached;
          isLoggedInObs.value = true;
          status.value = StatusRequest.success;
        }
      } else {
        status.value = StatusRequest.failure;
      }
    } catch (e) {
      status.value = StatusRequest.failure;
    }
  }
}
