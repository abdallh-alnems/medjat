import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
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

    final AuthController authController = Get.find<AuthController>();
    final hasAuth = await authController.checkAuth();
    if (!mounted) return;

    if (hasAuth) {
      unawaited(Get.offAllNamed<void>('/home'));
    } else {
      unawaited(Get.offAllNamed<void>('/login'));
    }
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
            const SizedBox(height: 8),
            Text(
              'لوحة تحكم الإدارة',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 16,
                color: colors.textSecondary,
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
