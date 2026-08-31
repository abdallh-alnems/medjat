import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../core/services/dark_light_service.dart';
import '../../controller/auth/auth_controller.dart';

class SettingsController extends GetxController {
  final DarkLightService _themeService = Get.find<DarkLightService>();
  final AuthController _authController = Get.find<AuthController>();

  bool get isDark => _themeService.isDark;

  void toggleTheme() => _themeService.toggleTheme();

  Future<void> logout() async {
    await _authController.logout();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      Get.back<void>();
      Get.snackbar('done'.tr, 'password_changed_success'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        Get.snackbar('error'.tr, 'current_password_wrong'.tr,
            snackPosition: SnackPosition.BOTTOM);
      } else if (e.code == 'requires-recent-login') {
        Get.snackbar('error'.tr, 'requires_recent_login'.tr,
            snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar('error'.tr, e.message ?? '',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint('changePassword error: $e');
      Get.snackbar('error'.tr, e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
