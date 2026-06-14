import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/token_storage_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../data/data_source/remote/admin_auth_data/admin_auth_data.dart';
import '../../../data/model/admin_model.dart';

class AuthController extends GetxController {
  final AdminAuthData _authData = Get.find<AdminAuthData>();

  final status = StatusRequest.none.obs;
  final isLoggedIn = false.obs;
  AdminModel? admin;

  @override
  void onInit() {
    super.onInit();
    _loadCachedAdmin();
  }

  Future<void> _loadCachedAdmin() async {
    admin = await _authData.getCachedAdmin();
    if (admin != null) {
      isLoggedIn.value = true;
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _authData.login(username: username, password: password);

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data?['admin'] != null) {
        admin = AdminModel.fromJson(data['admin'] as Map<String, dynamic>);
      } else if (data?['user'] != null) {
        admin = AdminModel.fromJson(data['user'] as Map<String, dynamic>);
      }
      isLoggedIn.value = true;
      status.value = StatusRequest.success;
      _initPushNotifications();
      unawaited(Get.offAllNamed<void>(AppRoutes.home));
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
      final statusCode = response['statusCode'];
      String message = response['message'] as String? ?? 'حدث خطأ، حاول مرة أخرى';

      if (statusCode == 401) {
        message = 'بيانات الدخول غير صحيحة';
      } else if (statusCode == 403) {
        message = 'الحساب معطّل، تواصل مع الإدارة';
      }

      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> logout() async {
    await _authData.logout();
    admin = null;
    isLoggedIn.value = false;
    unawaited(Get.offAllNamed<void>(AppRoutes.login));
  }

  Future<void> loadProfile() async {
    final response = await _authData.getProfile();
    if (response['status'] == StatusRequest.success && response['data'] != null) {
      final data = response['data']?['data'] ?? response['data'];
      admin = AdminModel.fromJson(data as Map<String, dynamic>);
      await TokenStorageService.saveUserData(jsonEncode(data));
      update();
    }
  }

  Future<bool> checkAuth() async {
    final hasToken = await TokenStorageService.hasToken();
    if (!hasToken) return false;
    await _loadCachedAdmin();
    if (admin != null) {
      _initPushNotifications();
    }
    return admin != null;
  }

  void _initPushNotifications() {
    try {
      final pushService = Get.find<PushNotificationService>();
      pushService.init();
    } catch (_) {}
  }
}
