import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/handling_data_request.dart';
import '../../../../core/constant/routes/app_routes.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../logic/controller/profile/profile_controller.dart';
import '../../widget/stat_item.dart';
import 'widgets/profile_header.dart';
import 'widgets/quick_access_card.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => ProfileController());
    return Scaffold(
      appBar: AppBar(
        title: Text('my_data'.tr),
      ),
      body: GetBuilder<ProfileController>(
        builder: (controller) {
          return HandlingDataRequest(
            statusRequest: controller.status,
            widget: _buildContent(context, controller),
            onRetry: () => controller.loadProfile(),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProfileController controller) {
    final emp = controller.profileData;
    if (emp == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileHeader(
            name: emp['name']?.toString() ?? '',
            jobTitle: emp['job_title']?.toString() ?? '',
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'employment_data'.tr),
          const SizedBox(height: 8),
          _infoCard(context, [
            _infoRow(context, 'job'.tr, emp['job_title']?.toString() ?? '-'),
            _infoRow(context, 'branch'.tr, emp['branch_name']?.toString() ?? '-'),
            _infoRow(context, 'hire_date'.tr, emp['hire_date']?.toString() ?? '-'),
            _infoRow(context, 'base_salary'.tr, emp['base_salary'] != null ? '${emp['base_salary']}' : '-'),
            _infoRow(context, 'status'.tr, emp['status']?.toString() ?? '-'),
          ]),
          if (controller.warnings.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle(context, '${'warnings'.tr} (${controller.warnings.length})'),
            const SizedBox(height: 8),
            _warningsCard(context, controller.warnings),
          ],
          if (controller.leaveBalance != null) ...[
            const SizedBox(height: 24),
            _sectionTitle(context, 'leave_balance'.tr),
            const SizedBox(height: 8),
            _balanceCard(context, controller.leaveBalance!),
          ],
          if (controller.categories.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle(context, 'categories'.tr),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: controller.categories.map((c) {
                return Chip(
                  label: Text(c['name']?.toString() ?? ''),
                  backgroundColor: AppColors.brand(context).withValues(alpha: 0.1),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
          _sectionTitle(context, 'quick_services'.tr),
          const SizedBox(height: 8),
          _quickAccessCards(context),
        ],
      ),
    );
  }

  Widget _quickAccessCards(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: QuickAccessCard(
                icon: Icons.folder_outlined,
                label: 'my_documents'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.myDocuments),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickAccessCard(
                icon: Icons.beach_access_outlined,
                label: 'leaves'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.leaves),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: QuickAccessCard(
                icon: Icons.free_breakfast_outlined,
                label: 'break_requests'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.breaks),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickAccessCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'advances'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.advances),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: QuickAccessCard(
                icon: Icons.inventory_2_outlined,
                label: 'my_assets'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.myAssets),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickAccessCard(
                icon: Icons.history_outlined,
                label: 'attendance_history'.tr,
                onTap: () => Get.toNamed<void>(AppRoutes.attendanceHistory),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(title, style: AppTextStyles.h3(context));
  }

  Widget _infoCard(BuildContext context, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySecondary(context)),
          Text(value, style: AppTextStyles.body(context)),
        ],
      ),
    );
  }

  Widget _warningsCard(BuildContext context, List<Map<String, dynamic>> warnings) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: warnings.map((w) {
          return ListTile(
            dense: true,
            leading: Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
            title: Text(w['reason']?.toString() ?? '', style: AppTextStyles.sm(context)),
            subtitle: Text(w['created_at']?.toString() ?? '', style: AppTextStyles.xs(context)),
          );
        }).toList(),
      ),
    );
  }

  Widget _balanceCard(BuildContext context, Map<String, dynamic> balance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          StatItem(label: 'balance'.tr, value: balance['total_days']?.toString() ?? '0'),
          StatItem(label: 'used'.tr, value: balance['used_days']?.toString() ?? '0'),
          StatItem(label: 'remaining'.tr, value: balance['remaining_days']?.toString() ?? '0'),
        ],
      ),
    );
  }
}
