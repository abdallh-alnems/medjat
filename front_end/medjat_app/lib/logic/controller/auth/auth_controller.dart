import 'dart:convert';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/services/token_storage_service.dart';
import '../../../data/data_source/remote/auth_data/auth_data.dart';
import '../../../data/model/user_model.dart';

class AuthController extends GetxController {
  final AuthData _authData = Get.find<AuthData>();

  final status = StatusRequest.none.obs;
  final isLoggedInObs = false.obs;
  UserModel? user;

  @override
  void onInit() {
    super.onInit();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    final hasToken = await TokenStorageService.hasToken();
    if (hasToken) {
      final cached = await _authData.getCachedUser();
      if (cached != null && cached.tenantId != 0) {
        user = cached;
        isLoggedInObs.value = true;
      }
    }
  }

  Future<void> login({
    required String phone,
    required String code,
  }) async {
    status.value = StatusRequest.loading;
    update();

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
          PushNotificationService.registerTokenNow();
          Get.offAllNamed<void>(AppRoutes.home);
        }
      } else {
        status.value = StatusRequest.failure;
        final statusCode = response['statusCode'];
        String message =
            (response['message'] as String?) ?? 'حدث خطأ، حاول مرة أخرى';

        if (statusCode == 403) {
          message = 'رقم الهاتف لا يطابق كود التفعيل';
        } else if (statusCode == 404) {
          message = 'كود التفعيل غير صالح أو منتهي';
        }

        Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      status.value = StatusRequest.failure;
      Get.snackbar('خطأ', 'حدث خطأ، حاول مرة أخرى',
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  bool isLoggedIn() {
    return isLoggedInObs.value && user != null;
  }

  Future<void> loadProfile() async {
    final response = await _authData.getProfile();
    if (response['status'] == StatusRequest.success &&
        response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      if (data['employee'] != null) {
        final emp = data['employee'] as Map<String, dynamic>;
        user = UserModel(
          id: (emp['id'] as int?) ?? 0,
          tenantId: (emp['tenant_id'] as int?) ?? 0,
          branchId: (emp['branch_id'] as int?) ?? 0,
          name: (emp['name'] as String?) ?? '',
          email: '',
          phone: emp['phone'] as String?,
          photoUrl: (emp['profile_image'] as String?) ??
              (emp['photo_url'] as String?),
          roleKey: 'employee',
          jobTitle: emp['job_title'] as String?,
          branchName: emp['branch_name'] as String?,
        );
        await TokenStorageService.saveUserData(jsonEncode(user!.toJson()));
        update();
      }
    }
  }

  Future<void> logout() async {
    await _authData.logout();
    user = null;
    isLoggedInObs.value = false;
    Get.offAllNamed<void>(AppRoutes.login);
  }

  Future<bool> checkAuth() async {
    final hasToken = await TokenStorageService.hasToken();
    if (!hasToken) return false;

    final cached = await _authData.getCachedUser();
    if (cached != null) {
      user = cached;
      isLoggedInObs.value = true;
      return true;
    }
    return false;
  }
}
