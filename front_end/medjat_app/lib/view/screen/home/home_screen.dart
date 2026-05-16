import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {},
          color: colors.brand,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            children: [
              const SizedBox(height: AppSpacing.s4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GetBuilder<AuthController>(
                    builder: (c) => Text(
                      'مرحباً، ${c.user?.name.split(' ').firstOrNull ?? ''}',
                      style: AppTextStyles.h3(context),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.notifications_outlined,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s7),
              Text(
                'الخميس — ١٦ مايو ٢٠٢٦',
                textAlign: TextAlign.center,
                style: AppTextStyles.sm(context),
              ),
              const SizedBox(height: AppSpacing.s6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s5),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.borderHairline, width: 1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: colors.surface,
                ),
                child: Column(
                  children: [
                    Text('حالتك اليوم', style: AppTextStyles.xs(context)),
                    const SizedBox(height: AppSpacing.s2),
                    Text('لم يتم تسجيل الحضور', style: AppTextStyles.h3(context)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s7),
              Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.brand,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_scanner, size: 48, color: Colors.white),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          'تسجيل الحضور',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s7),
              Text(
                'فرعك: المعادي',
                textAlign: TextAlign.center,
                style: AppTextStyles.sm(context),
              ),
              const SizedBox(height: AppSpacing.s9),
            ],
          ),
        ),
      ),
    );
  }
}
