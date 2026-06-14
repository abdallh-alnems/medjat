import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../data/model/user_model.dart';
import '../../../logic/controller/user/user_controller.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستخدمين')),
      body: GetBuilder<UserController>(
        builder: (controller) {
          return HandlingDataRequest(
            statusRequest: controller.status.value,
            onRetry: () => controller.loadUsers(),
            widget: RefreshIndicator(
              onRefresh: () => controller.loadUsers(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                itemCount: controller.users.length,
                itemBuilder: (context, index) {
                  return _UserCard(user: controller.users[index]);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        border: Border.all(color: colors.borderHairline),
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: colors.surface,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.brandSubtle,
            child: Text(
              user.name.isNotEmpty ? user.name[0] : '?',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
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
                  user.name,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (user.email != null)
                  Text(user.email!, style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: colors.textTertiary)),
                if (user.roleLabelAr != null)
                  Text(user.roleLabelAr!, style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 12, color: colors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: user.isActiveUser
                  ? colors.success.withValues(alpha: 0.1)
                  : colors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              user.isActiveUser ? 'نشط' : 'معطّل',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: user.isActiveUser ? colors.success : colors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
