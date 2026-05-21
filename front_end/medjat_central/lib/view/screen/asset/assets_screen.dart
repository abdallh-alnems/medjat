import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/asset/asset_controller.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/asset_custody_model.dart';
import '../../../data/model/employee_model.dart';

const _assetTypes = [
  'equipment',
  'device',
  'money',
  'vehicle',
  'document',
  'other',
];

class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put<AssetController>(AssetController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('assets'.tr)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_asset',
        onPressed: () => _showCreateSheet(context, ctrl),
        backgroundColor: colors.brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s2,
            ),
            child: Row(
              children: [
                _Chip(
                  label: 'all'.tr,
                  selected: ctrl.statusFilter == null,
                  onTap: () => ctrl.filterByStatus(null),
                ),
                const SizedBox(width: AppSpacing.s2),
                _Chip(
                  label: 'asset_status_assigned'.tr,
                  selected: ctrl.statusFilter == 'assigned',
                  onTap: () => ctrl.filterByStatus('assigned'),
                ),
                const SizedBox(width: AppSpacing.s2),
                _Chip(
                  label: 'asset_status_return_requested'.tr,
                  selected: ctrl.statusFilter == 'return_requested',
                  onTap: () => ctrl.filterByStatus('return_requested'),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadAssets,
              child: GetBuilder<AssetController>(
                builder: (_) {
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadAssets,
                    widget: ctrl.assets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined,
                                    size: 48, color: colors.textTertiary),
                                const SizedBox(height: AppSpacing.s3),
                                Text('no_assets'.tr,
                                    style:
                                        AppTextStyles.bodySecondary(context)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.s4,
                              0,
                              AppSpacing.s4,
                              AppSpacing.s7,
                            ),
                            itemCount: ctrl.assets.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s2),
                            itemBuilder: (_, i) => _AssetTile(
                              asset: ctrl.assets[i],
                              onConfirmReturn: () =>
                                  ctrl.approveReturn(ctrl.assets[i].id),
                              onRejectReturn: () => _showRejectDialog(
                                  context, ctrl, ctrl.assets[i].id),
                            ),
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, AssetController ctrl, int id) {
    final reasonCtrl = TextEditingController();
    final colors = AppColors.of(context);

    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('asset_reject_return'.tr,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
          content: TextField(
            controller: reasonCtrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'rejection_reason'.tr,
              hintStyle: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                color: colors.textTertiary,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back<void>(),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () {
                Get.back<void>();
                ctrl.rejectReturn(id,
                    reason: reasonCtrl.text.trim().isNotEmpty
                        ? reasonCtrl.text.trim()
                        : null);
              },
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text('reject'.tr),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, AssetController ctrl) {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final serialCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final descCtrl = TextEditingController();
    int? selectedEmployeeId;
    String selectedType = 'equipment';
    DateTime assignedDate = DateTime.now();

    final employeeData = Get.find<EmployeeData>();

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setSheetState) {
          final colors = AppColors.of(context);
          final isMoney = selectedType == 'money';
          return Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('asset_assign'.tr, style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s4),
                  _label('select_employee'.tr, colors),
                  const SizedBox(height: AppSpacing.s2),
                  FutureBuilder<List<EmployeeModel>>(
                    future: _loadEmployees(employeeData),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: Padding(
                          padding: EdgeInsets.all(AppSpacing.s3),
                          child: CircularProgressIndicator.adaptive(),
                        ));
                      }
                      final list = snapshot.data ?? [];
                      return _employeeDropdown(
                        value: selectedEmployeeId,
                        list: list,
                        colors: colors,
                        onChanged: (v) =>
                            setSheetState(() => selectedEmployeeId = v),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _label('asset_type'.tr, colors),
                  const SizedBox(height: AppSpacing.s2),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: _assetTypes
                        .map((t) => _Chip(
                              label: 'asset_type_$t'.tr,
                              selected: selectedType == t,
                              onTap: () =>
                                  setSheetState(() => selectedType = t),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'asset_name'.tr,
                    controller: nameCtrl,
                    hint: 'asset_name_hint'.tr,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: isMoney ? 'asset_amount'.tr : 'asset_value'.tr,
                    controller: valueCtrl,
                    hint: isMoney ? 'asset_amount'.tr : 'asset_value'.tr,
                    keyboardType: TextInputType.number,
                  ),
                  if (!isMoney) ...[
                    const SizedBox(height: AppSpacing.s3),
                    PrimaryInput(
                      label: 'asset_serial'.tr,
                      controller: serialCtrl,
                      hint: 'asset_serial'.tr,
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    PrimaryInput(
                      label: 'asset_quantity'.tr,
                      controller: qtyCtrl,
                      hint: 'asset_quantity'.tr,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s3),
                  _DatePickerField(
                    label: 'asset_assigned_at'.tr,
                    value: assignedDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: assignedDate,
                        firstDate: DateTime(2023, 1, 1),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setSheetState(() => assignedDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'asset_notes'.tr,
                    controller: descCtrl,
                    hint: 'asset_notes'.tr,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  PrimaryButton(
                    text: 'save'.tr,
                    onPressed: () async {
                      if (selectedEmployeeId == null) {
                        Get.snackbar('error'.tr, 'select_employee'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      if (nameCtrl.text.trim().isEmpty) {
                        Get.snackbar('error'.tr, 'asset_name_required'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      final value = double.tryParse(valueCtrl.text.trim());
                      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                      final ok = await ctrl.createAsset(
                        employeeId: selectedEmployeeId!,
                        type: selectedType,
                        name: nameCtrl.text,
                        assignedAt: assignedDate,
                        value: value,
                        serialNo: isMoney ? null : serialCtrl.text,
                        quantity: isMoney ? 1 : (qty < 1 ? 1 : qty),
                        notes: descCtrl.text,
                      );
                      if (ok) Get.back<void>();
                    },
                  ),
                  const SizedBox(height: AppSpacing.s4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<List<EmployeeModel>> _loadEmployees(EmployeeData employeeData) async {
  final response = await employeeData.getEmployees();
  dynamic payload = response['data'];
  if (payload is Map && payload['data'] != null) {
    payload = payload['data'];
  }
  List<dynamic>? items;
  if (payload is List) {
    items = payload;
  } else if (payload is Map) {
    for (final key in const ['items', 'records', 'list', 'data']) {
      if (payload[key] is List) {
        items = payload[key] as List;
        break;
      }
    }
  }
  return items
          ?.whereType<Map<String, dynamic>>()
          .map(EmployeeModel.fromJson)
          .toList() ??
      [];
}

Widget _employeeDropdown({
  required int? value,
  required List<EmployeeModel> list,
  required AppColorScheme colors,
  required void Function(int?) onChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
    decoration: BoxDecoration(
      color: colors.sunken,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: colors.borderHairline),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        isExpanded: true,
        hint: Text('select_employee'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              color: colors.textTertiary,
            )),
        value: value,
        items: list
            .map((e) => DropdownMenuItem<int>(
                  value: e.id,
                  child: Text(e.name,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                      )),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

Widget _label(String text, AppColorScheme colors) {
  return Text(text,
      style: TextStyle(
        fontFamily: 'IBM Plex Sans Arabic',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ));
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: _label(label, colors),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
            decoration: BoxDecoration(
              color: colors.sunken,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 18, color: colors.brand),
                const SizedBox(width: AppSpacing.s2),
                Text(
                  value != null
                      ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
                      : label,
                  style: TextStyle(
                    fontFamily:
                        value != null ? 'Geist' : 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: value != null
                        ? colors.textPrimary
                        : colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.brandSubtle : colors.sunken,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? colors.brand : colors.borderHairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? colors.brand : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final AssetCustodyModel asset;
  final VoidCallback onConfirmReturn;
  final VoidCallback onRejectReturn;

  const _AssetTile({
    required this.asset,
    required this.onConfirmReturn,
    required this.onRejectReturn,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(asset.status, colors);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  asset.name,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2,
                  vertical: AppSpacing.s1,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  asset.statusLabel,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.s1),
              Expanded(
                child: Text(
                  asset.employeeName ?? 'employee'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              _TypePill(label: asset.typeLabel, colors: colors),
            ],
          ),
          if (asset.value != null && asset.value! > 0) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Text(asset.type == 'money' ? 'asset_amount'.tr : 'asset_value'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.textTertiary,
                    )),
                const Spacer(),
                Text(
                  '${asset.value!.toStringAsFixed(2)} ${asset.currency}',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
          if (asset.serialNo != null && asset.serialNo!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s1),
            Text('${'asset_serial'.tr}: ${asset.serialNo}',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 12,
                  color: colors.textTertiary,
                )),
          ],
          if (asset.quantity > 1) ...[
            const SizedBox(height: AppSpacing.s1),
            Text('${'asset_quantity'.tr}: ${asset.quantity}',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 12,
                  color: colors.textTertiary,
                )),
          ],
          const SizedBox(height: AppSpacing.s1),
          Text(
            '${'asset_assigned_at'.tr}: ${asset.assignedAt.year}-${asset.assignedAt.month.toString().padLeft(2, '0')}-${asset.assignedAt.day.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12,
              color: colors.textTertiary,
            ),
          ),
          if (asset.notes != null && asset.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(asset.notes!, style: AppTextStyles.sm(context)),
          ],
          if (asset.status == 'return_requested' &&
              asset.returnNote != null &&
              asset.returnNote!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.assignment_return_outlined,
                    size: 14, color: colors.warning),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    asset.returnNote!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (asset.rejectionReason != null &&
              asset.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.block, size: 14, color: colors.error),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    asset.rejectionReason!,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 12,
                      color: colors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (asset.status == 'return_requested') ...[
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onConfirmReturn,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      foregroundColor: colors.success,
                    ),
                    child: Text('asset_confirm_return'.tr),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: TextButton(
                    onPressed: onRejectReturn,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.error,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: Text('reject'.tr),
                  ),
                ),
              ],
            ),
          ],
          if (asset.status == 'assigned') ...[
            const SizedBox(height: AppSpacing.s3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onConfirmReturn,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text('asset_mark_returned'.tr),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  foregroundColor: colors.success,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status, AppColorScheme colors) {
    switch (status) {
      case 'assigned':
        return colors.brand;
      case 'return_requested':
        return colors.warning;
      case 'returned':
        return colors.success;
      default:
        return colors.textTertiary;
    }
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final AppColorScheme colors;

  const _TypePill({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s2,
        vertical: AppSpacing.s1,
      ),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 11,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
