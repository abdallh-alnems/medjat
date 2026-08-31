import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constant/routes/app_routes.dart';
import '../../logic/controller/auth/auth_controller.dart';

class AuthMiddleware extends GetMiddleware {
  @override
  int? get priority => 1;

  @override
  redirect(String? route) {
    final auth = Get.find<AuthController>();

    final publicRoutes = [AppRoutes.splash, AppRoutes.login];

    if (publicRoutes.contains(route)) {
      if (auth.isLoggedIn.value && auth.user != null) {
        return const RouteSettings(name: AppRoutes.home);
      }
      return null;
    }

    if (!auth.isLoggedIn.value || auth.user == null) {
      return const RouteSettings(name: AppRoutes.login);
    }

    return null;
  }
}
