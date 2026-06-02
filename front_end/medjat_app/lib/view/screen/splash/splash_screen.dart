import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/services/token_storage_service.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final stationToken = await TokenStorageService.getStationToken();
    if (stationToken != null && stationToken.isNotEmpty) {
      Get.offAllNamed<void>(AppRoutes.kioskHome);
      return;
    }

    final hasToken = await TokenStorageService.hasToken();
    if (!hasToken) {
      Get.offAllNamed<void>(AppRoutes.login);
      return;
    }

    final userData = await TokenStorageService.getUserData();
    if (userData != null) {
      try {
        final json = jsonDecode(userData) as Map<String, dynamic>;
        final tenantId = json['tenant_id'];
        if (tenantId != null && tenantId != 0) {
          final authController = Get.find<AuthController>();
          await authController.checkAuth();
          Get.offAllNamed<void>(AppRoutes.home);
          return;
        }
      } catch (_) {}
    }

    Get.offAllNamed<void>(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Medjat',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: colors.brand,
                letterSpacing: -0.02,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(colors.textTertiary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'جاري التحميل...',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
