import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/constant/routes/app_routes.dart';
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
          GetBuilder<AuthController>(
            builder: (auth) => Container(
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
                        if (auth.user?.phone != null &&
                            auth.user!.phone!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            auth.user!.phone!,
                            style: AppTextStyles.sm(context),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                        if (auth.user != null &&
                            auth.user!.roleKey.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s2),
                          _RoleChip(roleKey: auth.user!.roleKey),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _AccountTile(
            icon: Icons.edit_outlined,
            title: 'change_personal_info'.tr,
            onTap: () => _showEditProfileSheet(context, auth),
          ),
          const SizedBox(height: AppSpacing.s2),
          _AccountTile(
            icon: Icons.lock_outline,
            title: 'change_password'.tr,
            onTap: () => _showChangePasswordSheet(context),
          ),
          const SizedBox(height: AppSpacing.s2),
          _AccountTile(
            icon: Icons.notifications_outlined,
            title: 'notification_settings'.tr,
            onTap: () => Get.toNamed<void>(AppRoutes.notificationPrefs),
          ),
          const SizedBox(height: AppSpacing.s5),
          Center(
            child: TextButton(
              onPressed: () => _confirmLogout(context, settingsCtrl),
              style: TextButton.styleFrom(
                foregroundColor: colors.error,
              ),
              child: Text('logout'.tr),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Center(
            child: TextButton.icon(
              onPressed: () => _confirmDeleteAccount(context, auth),
              icon: Icon(Icons.delete_forever_outlined,
                  size: 18, color: colors.error),
              style: TextButton.styleFrom(
                foregroundColor: colors.error,
              ),
              label: Text('delete_account'.tr),
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
        ],
      ),
    );
  }
}

/// Confirms before signing the user out.
void _confirmLogout(BuildContext context, SettingsController settingsCtrl) {
  final colors = AppColors.of(context);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('logout_confirm_title'.tr),
      content: Text('logout_confirm_message'.tr),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('cancel'.tr),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            settingsCtrl.logout();
          },
          style: TextButton.styleFrom(foregroundColor: colors.error),
          child: Text('logout'.tr),
        ),
      ],
    ),
  );
}

/// Confirms before permanently deleting the account. A general manager is
/// warned that the whole company may be deleted (the backend decides whether
/// they are the last one).
void _confirmDeleteAccount(BuildContext context, AuthController auth) {
  final colors = AppColors.of(context);
  final isGeneralManager = auth.user?.isGeneralManager == true;
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('delete_account_confirm_title'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('delete_account_confirm_message'.tr),
          if (isGeneralManager) ...[
            const SizedBox(height: AppSpacing.s3),
            Text(
              'delete_account_warning_company'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('cancel'.tr),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            auth.deleteAccount();
          },
          style: TextButton.styleFrom(foregroundColor: colors.error),
          child: Text('delete'.tr),
        ),
      ],
    ),
  );
}

/// Localized label for an admin role key (falls back to the raw key).
String _roleLabel(String roleKey) {
  const map = {
    'general_manager': 'role_general_manager',
    'hr': 'role_hr',
    'branch_manager': 'role_branch_manager',
    'attendance': 'role_attendance',
    'viewer': 'role_viewer',
    'pending': 'role_pending',
  };
  final key = map[roleKey];
  return key != null ? key.tr : roleKey;
}

/// Bottom sheet to edit the signed-in user's own name and phone.
void _showEditProfileSheet(BuildContext context, AuthController auth) {
  final colors = AppColors.of(context);
  final nameCtrl = TextEditingController(text: auth.user?.name ?? '');
  final phoneCtrl = TextEditingController(text: auth.user?.phone ?? '');
  final formKey = GlobalKey<FormState>();

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
              'change_personal_info'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            TextFormField(
              controller: nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'name'.tr,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'enter_name'.tr;
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s3),
            TextFormField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'phone_optional'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            Obx(() => SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: auth.isUpdatingProfile.value
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            await auth.updateProfile(
                              name: nameCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    child: auth.isUpdatingProfile.value
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
                            'save_changes'.tr,
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

/// Small pill showing the user's role next to their name.
class _RoleChip extends StatelessWidget {
  final String roleKey;

  const _RoleChip({required this.roleKey});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 2),
      decoration: BoxDecoration(
        color: colors.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        _roleLabel(roleKey),
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.brand,
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AccountTile({
    required this.icon,
    required this.title,
    required this.onTap,
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
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left
                  : Icons.chevron_right,
              size: 20,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
