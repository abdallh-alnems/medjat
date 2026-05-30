import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/model/branch_model.dart';
import '../../../logic/controller/branch/branch_controller.dart';

class BranchScreen extends StatelessWidget {
  const BranchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put<BranchController>(BranchController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('branches'.tr)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBranchSheet(context, ctrl),
        backgroundColor: colors.brand,
        child: Icon(Icons.add, color: Colors.white),
      ),
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
                          Text('no_branches'.tr,
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
                        cycleStartDay: ctrl.branches[i].cycleStartDay,
                        onTap: () => _showEditBranchSheet(
                            context, ctrl, ctrl.branches[i]),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  void _showAddBranchSheet(BuildContext context, BranchController ctrl) {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isLoading = false.obs;
    final branchData = Get.find<BranchData>();

    Get.bottomSheet<void>(
      Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.s5,
          right: AppSpacing.s5,
          top: AppSpacing.s5,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s5,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('add_branch'.tr,
                  style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: 'branch_name'.tr),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'required'.tr : null,
              ),
              const SizedBox(height: AppSpacing.s3),
              TextFormField(
                controller: addressCtrl,
                decoration: InputDecoration(labelText: 'branch_address'.tr),
              ),
              const SizedBox(height: AppSpacing.s5),
              Obx(() => PrimaryButton(
                    text: 'create'.tr,
                    isLoading: isLoading.value,
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      isLoading.value = true;
                      final resp = await branchData.createBranch({
                        'name': nameCtrl.text.trim(),
                        'address': addressCtrl.text.trim(),
                      });
                      isLoading.value = false;
                      if (resp['status'] == StatusRequest.success) {
                        Get.back();
                        Get.snackbar('done'.tr, 'branch_created_success'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                        await ctrl.loadBranches();
                      } else {
                        Get.snackbar('error'.tr, 'branch_creation_failed'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                  )),
            ],
          ),
        ),
      ),
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
    );
  }
}

void _showEditBranchSheet(
    BuildContext context, BranchController ctrl, BranchModel branch) {
  final nameCtrl = TextEditingController(text: branch.name);
  final addressCtrl = TextEditingController(text: branch.address ?? '');
  final cycleCtrl = TextEditingController(
      text: branch.cycleStartDay != null ? '${branch.cycleStartDay}' : '');
  final formKey = GlobalKey<FormState>();
  final isLoading = false.obs;
  final branchData = Get.find<BranchData>();

  Get.bottomSheet<void>(
    Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s5,
        right: AppSpacing.s5,
        top: AppSpacing.s5,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s5,
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('edit_branch'.tr,
                style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.s4),
            TextFormField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: 'branch_name'.tr),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'required'.tr : null,
            ),
            const SizedBox(height: AppSpacing.s3),
            TextFormField(
              controller: addressCtrl,
              decoration: InputDecoration(labelText: 'branch_address'.tr),
            ),
            const SizedBox(height: AppSpacing.s3),
            TextFormField(
              controller: cycleCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'branch_cycle_override'.tr,
                helperText: 'branch_cycle_override_hint'.tr,
                helperMaxLines: 2,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null || n < 1 || n > 28) {
                  return 'cycle_value_invalid'.tr;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s5),
            Obx(() => PrimaryButton(
                  text: 'save'.tr,
                  isLoading: isLoading.value,
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    isLoading.value = true;
                    final cycleText = cycleCtrl.text.trim();
                    final resp = await branchData.updateBranch(branch.id, {
                      'name': nameCtrl.text.trim(),
                      'address': addressCtrl.text.trim(),
                      'cycle_start_day':
                          cycleText.isEmpty ? null : int.parse(cycleText),
                    });
                    isLoading.value = false;
                    if (resp['status'] == StatusRequest.success) {
                      Get.back();
                      Get.snackbar('done'.tr, 'saved_successfully'.tr,
                          snackPosition: SnackPosition.BOTTOM);
                      await ctrl.loadBranches();
                    } else {
                      Get.snackbar('error'.tr,
                          (resp['message'] as String?) ?? 'error'.tr,
                          snackPosition: SnackPosition.BOTTOM);
                    }
                  },
                )),
          ],
        ),
      ),
    ),
    backgroundColor: Theme.of(context).cardColor,
    isScrollControlled: true,
  );
}

class _BranchTile extends StatelessWidget {
  final String name;
  final String address;
  final int employeeCount;
  final int? cycleStartDay;
  final VoidCallback onTap;

  const _BranchTile({
    required this.name,
    required this.address,
    required this.employeeCount,
    required this.cycleStartDay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
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
                if (cycleStartDay != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_repeat_outlined,
                          size: 12, color: colors.brand),
                      const SizedBox(width: 4),
                      Text(
                        'cycle_starts_on'.trParams({'day': '$cycleStartDay'}),
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.brand,
                        ),
                      ),
                    ],
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
                'employee'.tr,
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
      ),
    );
  }
}
