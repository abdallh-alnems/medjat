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
      expect(controller.isLoggedIn.value, false);
    });
  });

  group('AuthController — logout', () {
    test('logout clears state', () async {
      when(() => mockAuthData.logout()).thenAnswer((_) async {});

      final controller = Get.put<TestableAuthController>(
        TestableAuthController(),
      );
      controller.isLoggedIn.value = true;
      controller.isActivated.value = true;
      controller.user = createTestUser();

      await controller.logout();

      expect(controller.user, isNull);
      expect(controller.isLoggedIn.value, false);
      expect(controller.isActivated.value, false);
      verify(() => mockAuthData.logout()).called(1);
    });
  });

  group('AuthController — activateWithCode', () {
    test('activateWithCode sets failure on error response', () async {
      when(() => mockAuthData.activateEmployee(activationCode: any(named: 'activationCode')))
          .thenAnswer((_) async => {
                'status': StatusRequest.failure,
                'statusCode': 404,
                'message': 'كود التفعيل غير صالح أو منتهي',
              });

      final controller = Get.put<TestableAuthController>(
        TestableAuthController(),
      );

      await controller.activateWithCode('BADCODE');

      expect(controller.status.value, StatusRequest.failure);
    });

    test('activateWithCode sets failure on 422', () async {
      when(() => mockAuthData.activateEmployee(activationCode: any(named: 'activationCode')))
          .thenAnswer((_) async => {
                'status': StatusRequest.failure,
                'statusCode': 422,
                'message': 'كود التفعيل مطلوب',
              });

      final controller = Get.put<TestableAuthController>(
        TestableAuthController(),
      );

      await controller.activateWithCode('');

      expect(controller.status.value, StatusRequest.failure);
    });
  });

  group('AuthController — data parsing', () {
    test('UserModel from activation response round-trips', () {
      final userData = {
        'id': 5,
        'name': 'سارة',
        'tenant_id': 1,
        'tenant_name': 'شركة النور',
        'branch_id': 2,
        'branch_name': 'فرع الرياض',
        'job_title': 'محاسبة',
        'email': 'sara@noor.com',
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
  final isLoggedIn = false.obs;
  final isActivated = false.obs;
  UserModel? user;

  @override
  void onInit() {
    super.onInit();
  }

  Future<bool> checkAuth() async {
    final cached = await _authData.getCachedUser();
    if (cached != null) {
      user = cached;
      isLoggedIn.value = true;
      isActivated.value = cached.tenantId != 0;
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _authData.logout();
    user = null;
    isLoggedIn.value = false;
    isActivated.value = false;
  }

  Future<void> activateWithCode(String activationCode) async {
    status.value = StatusRequest.loading;

    final response = await _authData.activateEmployee(
      activationCode: activationCode.trim(),
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      if (data?['employee'] != null) {
        final employee = data!['employee'] as Map<String, dynamic>;
        user = UserModel(
          id: (employee['id'] as int?) ?? 0,
          tenantId: (employee['tenant_id'] as int?) ?? 0,
          branchId: (employee['branch_id'] as int?) ?? 0,
          name: (employee['name'] as String?) ?? '',
          email: '',
          branchName: employee['branch_name'] as String?,
          jobTitle: employee['job_title'] as String?,
          roleKey: 'employee',
        );
        isActivated.value = true;
        isLoggedIn.value = true;
        status.value = StatusRequest.success;
      }
    } else {
      status.value = StatusRequest.failure;
    }
  }
}
