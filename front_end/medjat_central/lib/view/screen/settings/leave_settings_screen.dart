import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/settings/leave_settings_controller.dart';

class LeaveSettingsScreen extends StatelessWidget {
  const LeaveSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(LeaveSettingsController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('leave_settings_title'.tr)),
      body: GetBuilder<LeaveSettingsController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.loadSettings,
            widget: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('leave_entitlement_section'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Text('leave_default_days_hint'.tr,
                      style: AppTextStyles.sm(context)),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'leave_default_days_label'.tr,
                    controller: ctrl.defaultDaysController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    hint: '21',
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Text('leave_carryover_section'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: colors.borderHairline),
                    ),
                    child: SwitchListTile(
                      title: Text('leave_carryover_enabled'.tr,
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          )),
                      subtitle: Text(
                        ctrl.carryoverEnabled
                            ? 'leave_carryover_on_hint'.tr
                            : 'leave_carryover_off_hint'.tr,
                        style: AppTextStyles.sm(context),
                      ),
                      value: ctrl.carryoverEnabled,
                      onChanged: ctrl.setCarryoverEnabled,
                      activeColor: colors.brand,
                    ),
                  ),
                  if (ctrl.carryoverEnabled) ...[
                    const SizedBox(height: AppSpacing.s3),
                    PrimaryInput(
                      label: 'leave_carryover_max_label'.tr,
                      controller: ctrl.carryoverDaysController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      hint: '0',
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s6),
                  PrimaryButton(
                    text: 'save'.tr,
                    isLoading: ctrl.saving,
                    onPressed: ctrl.saveSettings,
                  ),
                  const Divider(height: AppSpacing.s7 * 2),
                  Text('leave_rollover_section'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Text('leave_rollover_hint'.tr,
                      style: AppTextStyles.sm(context)),
                  const SizedBox(height: AppSpacing.s3),
                  OutlinedButton.icon(
                    onPressed: ctrl.rolloverRunning
                        ? null
                        : () => _confirmRollover(context, ctrl),
                    icon: ctrl.rolloverRunning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_alt, size: 18),
                    label: Text('leave_rollover_button'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.brand,
                      side: BorderSide(color: colors.brand),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmRollover(BuildContext context, LeaveSettingsController ctrl) {
    final fromYear = DateTime.now().year - 1;
    final toYear = fromYear + 1;
    Get.dialog<void>(
      AlertDialog(
        title: Text('leave_rollover_button'.tr,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            )),
        content: Text(
          'leave_rollover_confirm'.trParams({
            'from': fromYear.toString(),
            'to': toYear.toString(),
          }),
          style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back<void>();
              ctrl.runRollover(fromYear);
            },
            child: Text('confirm'.tr),
          ),
        ],
      ),
    );
  }
}
