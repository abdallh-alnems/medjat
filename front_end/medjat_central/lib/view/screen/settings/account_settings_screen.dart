import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/input_fields/password_input.dart';
import '../../../logic/controller/settings/settings_controller.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsCtrl = Get.find<SettingsController>();
    final auth = Get.find<AuthController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('my_account'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s5),
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colors.brandSubtle,
                  child: Text(
                    (auth.user != null && auth.user!.name.isNotEmpty)
                        ? auth.user!.name[0]
                        : '?',
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colors.brand,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.user?.name ?? 'admin'.tr,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        auth.user?.email ?? '',
                        style: AppTextStyles.sm(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _AccountTile(
            icon: Icons.edit_outlined,
            title: 'change_personal_info'.tr,
            onTap: () => _showEditProfileSheet(context),
          ),
          const SizedBox(height: AppSpacing.s2),
          _AccountTile(
            icon: Icons.lock_outline,
            title: 'change_password'.tr,
            onTap: () => _showChangePasswordSheet(context),
          ),
          const SizedBox(height: AppSpacing.s2),
          _AccountTile(
            icon: Icons.email_outlined,
            title: 'email'.tr,
            subtitle: auth.user?.email ?? '',
            showChevron: false,
            onTap: () {},
          ),
          const SizedBox(height: AppSpacing.s5),
          Center(
            child: TextButton(
              onPressed: settingsCtrl.logout,
              style: TextButton.styleFrom(
                foregroundColor: colors.error,
              ),
              child: Text('logout'.tr),
            ),
          ),
        ],
      ),
    );
  }
}

void _showEditProfileSheet(BuildContext context) {
  Get.snackbar('coming_soon'.tr, '',
      snackPosition: SnackPosition.BOTTOM);
}

void _showChangePasswordSheet(BuildContext context) {
  final settingsCtrl = Get.find<SettingsController>();
  final colors = AppColors.of(context);
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final isLoading = false.obs;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s4,
        right: AppSpacing.s4,
        top: AppSpacing.s5,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s4,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'change_password'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            PasswordInput(
              label: 'current_password',
              controller: currentCtrl,
              validator: (v) {
                if (v == null || v.isEmpty) return 'enter_password'.tr;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s3),
            PasswordInput(
              label: 'new_password',
              controller: newCtrl,
              validator: (v) {
                if (v == null || v.isEmpty) return 'enter_password'.tr;
                if (v.length < 6) return 'password_min_length'.tr;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s3),
            PasswordInput(
              label: 'confirm_new_password',
              controller: confirmCtrl,
              validator: (v) {
                if (v == null || v.isEmpty) return 'enter_password'.tr;
                if (v != newCtrl.text) return 'passwords_not_match'.tr;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s5),
            Obx(() => SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isLoading.value
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            isLoading.value = true;
                            await settingsCtrl.changePassword(
                              currentPassword: currentCtrl.text,
                              newPassword: newCtrl.text,
                            );
                            isLoading.value = false;
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    child: isLoading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'save'.tr,
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Sans Arabic',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                )),
          ],
        ),
      ),
    ),
  );
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showChevron;

  const _AccountTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.sm(context),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_left, size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
