import 'dart:convert';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/token_storage_service.dart';
import '../../../data/data_source/remote/auth_data/auth_data.dart';
import '../../../data/model/user_model.dart';

class AuthController extends GetxController {
  final AuthData _authData = Get.find<AuthData>();

  final status = StatusRequest.none.obs;
  final isLoggedIn = false.obs;
  UserModel? user;

  @override
  void onInit() {
    super.onInit();
    _loadCachedUser();
  }

  Future<void> _loadCachedUser() async {
    user = await _authData.getCachedUser();
    if (user != null) {
      isLoggedIn.value = true;
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _authData.login(email: email, password: password);

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data?['user'] != null) {
        user = UserModel.fromJson(data['user']);
      }
      isLoggedIn.value = true;
      status.value = StatusRequest.success;
      Get.offAllNamed(AppRoutes.home);
    } else {
      status.value = response['status'] ?? StatusRequest.failure;
      final statusCode = response['statusCode'];
      String message = response['message'] ?? 'حدث خطأ، حاول مرة أخرى';

      if (statusCode == 401) {
        message = 'بيانات الدخول غير صحيحة';
      } else if (statusCode == 403) {
        message = 'الشركة متوقفة، تواصل مع الإدارة';
      }

      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> logout() async {
    await _authData.logout();
    user = null;
    isLoggedIn.value = false;
    Get.offAllNamed(AppRoutes.login);
  }

  Future<void> loadProfile() async {
    final response = await _authData.getProfile();
    if (response['status'] == StatusRequest.success && response['data'] != null) {
      user = UserModel.fromJson(response['data']);
      await TokenStorageService.saveUserData(jsonEncode(response['data']));
      update();
    }
  }

  Future<bool> checkAuth() async {
    final hasToken = await TokenStorageService.hasToken();
    if (!hasToken) return false;
    await _loadCachedUser();
    return user != null;
  }
}
