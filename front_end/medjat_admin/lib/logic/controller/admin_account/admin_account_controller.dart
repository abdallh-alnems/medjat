import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/admin_account_data/admin_account_data.dart';

class AdminAccountController extends GetxController {
  final AdminAccountData _data = Get.find<AdminAccountData>();

  final status = StatusRequest.none.obs;

  /// Creates a new login account for the admin app (super_admins).
  /// Returns true on success.
  Future<bool> create({
    required String username,
    required String password,
    required String role,
    String? displayName,
    String? email,
  }) async {
    status.value = StatusRequest.loading;

    final response = await _data.create(
      username: username,
      password: password,
      role: role,
      displayName: displayName,
      email: email,
    );

    if (response['status'] == StatusRequest.success) {
      status.value = StatusRequest.success;
      Get.snackbar('تم', 'تم إنشاء حساب المشرف بنجاح', snackPosition: SnackPosition.BOTTOM);
      return true;
    }

    status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    final message = response['message'] as String? ?? 'تعذّر إنشاء الحساب';
    Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    return false;
  }
}
