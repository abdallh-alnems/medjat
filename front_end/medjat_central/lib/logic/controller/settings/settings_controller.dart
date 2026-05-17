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
}
