import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/handling_data_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../logic/controller/profile/profile_controller.dart';

class MyDocumentsScreen extends StatelessWidget {
  const MyDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => ProfileController());
    return Scaffold(
      appBar: AppBar(title: const Text('أوراقي')),
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
    if (controller.documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: AppColors.textTertiary(context)),
            const SizedBox(height: 16),
            Text('لا توجد مستندات', style: AppTextStyles.bodySecondary(context)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.documents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final doc = controller.documents[index];
        return _documentCard(context, doc);
      },
    );
  }

  Widget _documentCard(BuildContext context, Map<String, dynamic> doc) {
    final status = doc['status']?.toString() ?? '';
    final isExpired = status == 'expired';
    final isPending = status == 'pending' || status == 'required';
    final isVerified = status == 'verified';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isVerified) {
      statusColor = Colors.green;
      statusText = 'معتمد';
      statusIcon = Icons.verified;
    } else if (isExpired) {
      statusColor = Colors.red;
      statusText = 'منتهي';
      statusIcon = Icons.error;
    } else if (isPending) {
      statusColor = Colors.orange;
      statusText = 'مطلوب';
      statusIcon = Icons.pending;
    } else {
      statusColor = Colors.grey;
      statusText = status;
      statusIcon = Icons.description;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc['document_type_name']?.toString() ?? doc['name']?.toString() ?? 'مستند',
                  style: AppTextStyles.body(context),
                ),
                if (doc['expiry_date'] != null) ...[
                  const SizedBox(height: 2),
                  Text('ينتهي: ${doc['expiry_date']}', style: AppTextStyles.xs(context)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
