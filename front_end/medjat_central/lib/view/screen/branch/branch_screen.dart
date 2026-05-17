import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/branch/branch_controller.dart';

class BranchScreen extends StatelessWidget {
  const BranchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put<BranchController>(BranchController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الفروع')),
      body: RefreshIndicator(
        onRefresh: ctrl.loadBranches,
        child: GetBuilder<BranchController>(
          builder: (_) {
            return HandlingDataRequest(
              statusRequest: ctrl.status,
              onRetry: ctrl.loadBranches,
              widget: ctrl.branches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_tree_outlined,
                              size: 48, color: colors.textTertiary),
                          const SizedBox(height: AppSpacing.s3),
                          Text('لا يوجد فروع',
                              style: AppTextStyles.bodySecondary(context)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      itemCount: ctrl.branches.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s3),
                      itemBuilder: (_, i) => _BranchTile(
                        name: ctrl.branches[i].name,
                        address: ctrl.branches[i].address ?? '',
                        employeeCount: ctrl.branches[i].employeeCount,
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _BranchTile extends StatelessWidget {
  final String name;
  final String address;
  final int employeeCount;

  const _BranchTile({
    required this.name,
    required this.address,
    required this.employeeCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.brandSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.store_outlined, color: colors.brand, size: 22),
          ),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 13,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$employeeCount',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.brand,
                ),
              ),
              Text(
                'موظف',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  color: colors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
