import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/admin_auth_data/admin_auth_data.dart';
import '../auth/auth_controller.dart';

/// Our own account: the profile, and the password change that keeps a forgotten
/// password from becoming hand-written SQL on the production server.
class AccountController extends GetxController {
  final AdminAuthData _authData = Get.find<AdminAuthData>();

  final status = StatusRequest.none.obs;
  final busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadProfile();
  }

  Future<void> loadProfile() async {
    status.value = StatusRequest.loading;
    update();
    await Get.find<AuthController>().loadProfile();
    status.value = StatusRequest.success;
    update();
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    busy.value = true;
    update();

    final response = await _authData.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    busy.value = false;
    update();

    if (response['status'] == StatusRequest.success) {
      Get.snackbar(
        'تم',
        'تم تغيير كلمة المرور، وسُجّل خروج بقية الأجهزة',
        snackPosition: SnackPosition.BOTTOM,
      );
      await loadProfile();
      return true;
    }

    Get.snackbar(
      'خطأ',
      response['message'] as String? ?? 'تعذّر تغيير كلمة المرور',
      snackPosition: SnackPosition.BOTTOM,
    );
    return false;
  }
}
