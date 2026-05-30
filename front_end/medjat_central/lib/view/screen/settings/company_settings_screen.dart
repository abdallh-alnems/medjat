import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/settings/company_settings_controller.dart';

class CompanySettingsScreen extends StatelessWidget {
  const CompanySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(CompanySettingsController());

    return Scaffold(
      appBar: AppBar(title: Text('company_data'.tr)),
      body: GetBuilder<CompanySettingsController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.loadSettings,
            widget: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CompanyHeader(ctrl: ctrl),
                  const SizedBox(height: AppSpacing.s5),
                  Text('company_data'.tr, style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s4),
                  PrimaryInput(
                    label: 'company_name'.tr,
                    controller: ctrl.nameController,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'address'.tr,
                    controller: ctrl.addressController,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'phone'.tr,
                    controller: ctrl.phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'email'.tr,
                    controller: ctrl.emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Text('attendance_cycle'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Text('cycle_start_day_hint'.tr,
                      style: AppTextStyles.sm(context)),
                  const SizedBox(height: AppSpacing.s3),
                  _CycleStartDayField(ctrl: ctrl),
                  const SizedBox(height: AppSpacing.s6),
                  GetBuilder<CompanySettingsController>(
                    builder: (_) {
                      return PrimaryButton(
                        text: 'save_changes'.tr,
                        isLoading: ctrl.status == StatusRequest.loading,
                        onPressed: ctrl.saveSettings,
                      );
                    },
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
}

/// A compact stepper (− value +) for the company cycle start day (1-28).
class _CycleStartDayField extends StatelessWidget {
  final CompanySettingsController ctrl;
  const _CycleStartDayField({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GetBuilder<CompanySettingsController>(
      builder: (_) {
        final from = ctrl.cycleStartDay;
        final previewText = from <= 1
            ? 'cycle_normal_month'.tr
            : 'cycle_window_preview'
                .trParams({'from': '$from', 'to': '${from - 1}'});
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
                      'cycle_start_day_label'.tr,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: from > 1
                        ? () => ctrl.setCycleStartDay(from - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: colors.brand,
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$from',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.brand,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: from < 28
                        ? () => ctrl.setCycleStartDay(from + 1)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    color: colors.brand,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(previewText, style: AppTextStyles.sm(context)),
            ],
          ),
        );
      },
    );
  }
}

class _CompanyHeader extends StatelessWidget {
  final CompanySettingsController ctrl;
  const _CompanyHeader({required this.ctrl});

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
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.brandSubtle,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.business, size: 28, color: colors.brand),
          ),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctrl.nameController.text.isEmpty
                      ? 'the_company'.tr
                      : ctrl.nameController.text,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ctrl.addressController.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    ctrl.addressController.text,
                    style: AppTextStyles.sm(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
