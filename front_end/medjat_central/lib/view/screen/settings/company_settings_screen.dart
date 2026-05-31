import 'dart:io';
import 'package:file_picker/file_picker.dart';
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

/// ISO currency codes offered in the picker. Labels come from `curr_<code>`.
const List<String> _kCurrencies = [
  'EGP',
  'SAR',
  'AED',
  'USD',
  'EUR',
  'KWD',
  'QAR',
];

/// IANA timezones offered in the picker. Labels come from
/// `tz_<id lowercased, / → _>`.
const List<String> _kTimezones = [
  'Africa/Cairo',
  'Asia/Riyadh',
  'Asia/Dubai',
  'Asia/Kuwait',
  'Asia/Qatar',
  'Asia/Baghdad',
  'Asia/Amman',
  'Europe/London',
  'UTC',
];

String _currencyLabel(String code) {
  final name = 'curr_${code.toLowerCase()}'.tr;
  return '$name ($code)';
}

String _timezoneLabel(String id) =>
    'tz_${id.toLowerCase().replaceAll('/', '_')}'.tr;

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
                    label: 'commercial_register'.tr,
                    controller: ctrl.commercialRegisterController,
                  ),

                  // ── Company letterhead (logo / stamp / signature) ──
                  const SizedBox(height: AppSpacing.s6),
                  Text('company_branding'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Text('company_branding_hint'.tr,
                      style: AppTextStyles.sm(context)),
                  const SizedBox(height: AppSpacing.s3),
                  _BrandingTile(
                    ctrl: ctrl,
                    type: 'logo',
                    icon: Icons.image_outlined,
                    title: 'logo'.tr,
                    uploaded: ctrl.hasLogo,
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  _BrandingTile(
                    ctrl: ctrl,
                    type: 'stamp',
                    icon: Icons.approval_outlined,
                    title: 'stamp'.tr,
                    uploaded: ctrl.hasStamp,
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  _BrandingTile(
                    ctrl: ctrl,
                    type: 'signature',
                    icon: Icons.draw_outlined,
                    title: 'signature'.tr,
                    uploaded: ctrl.hasSignature,
                  ),

                  // ── Currency & timezone ──
                  const SizedBox(height: AppSpacing.s6),
                  Text('localization_section'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s4),
                  _PickerField(
                    label: 'currency_label'.tr,
                    value: _currencyLabel(ctrl.currency),
                    icon: Icons.attach_money,
                    onTap: () => _pickOption(
                      context,
                      title: 'currency_label'.tr,
                      options: _kCurrencies,
                      selected: ctrl.currency,
                      labelOf: _currencyLabel,
                      onSelected: ctrl.setCurrency,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _PickerField(
                    label: 'timezone_label'.tr,
                    value: _timezoneLabel(ctrl.timezone),
                    icon: Icons.public,
                    onTap: () => _pickOption(
                      context,
                      title: 'timezone_label'.tr,
                      options: _kTimezones,
                      selected: ctrl.timezone,
                      labelOf: _timezoneLabel,
                      onSelected: ctrl.setTimezone,
                    ),
                  ),

                  // ── Attendance cycle ──
                  const SizedBox(height: AppSpacing.s6),
                  Text('attendance_cycle'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Text('cycle_start_day_hint'.tr,
                      style: AppTextStyles.sm(context)),
                  const SizedBox(height: AppSpacing.s3),
                  _CycleStartDayField(ctrl: ctrl),
                  const SizedBox(height: AppSpacing.s6),
                  PrimaryButton(
                    text: 'save_changes'.tr,
                    isLoading: ctrl.status == StatusRequest.loading,
                    onPressed: ctrl.saveSettings,
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

  /// Shows a bottom-sheet list of [options] and reports the chosen value.
  void _pickOption(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selected,
    required String Function(String) labelOf,
    required void Function(String) onSelected,
  }) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Text(title, style: AppTextStyles.h3(context)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options.map((o) {
                  final isSelected = o == selected;
                  return ListTile(
                    title: Text(
                      labelOf(o),
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? colors.brand
                            : colors.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: colors.brand)
                        : null,
                    onTap: () {
                      onSelected(o);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
        ),
      ),
    );
  }
}

/// A read-only field that opens a picker when tapped (used for currency/timezone).
class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
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
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.04,
              color: colors.textSecondary,
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colors.textTertiary),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(Icons.expand_more, size: 20, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One letterhead asset row: shows its upload state and lets the user pick an
/// image to upload or replace it.
class _BrandingTile extends StatelessWidget {
  final CompanySettingsController ctrl;
  final String type;
  final IconData icon;
  final String title;
  final bool uploaded;

  const _BrandingTile({
    required this.ctrl,
    required this.type,
    required this.icon,
    required this.title,
    required this.uploaded,
  });

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    final path = result?.files.single.path;
    if (path != null) {
      await ctrl.uploadBranding(type, File(path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isUploading = ctrl.uploadingType == type;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
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
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 22, color: colors.brand),
          ),
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
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      uploaded
                          ? Icons.check_circle
                          : Icons.remove_circle_outline,
                      size: 13,
                      color: uploaded ? colors.success : colors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      uploaded ? 'uploaded'.tr : 'not_set'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 12,
                        color:
                            uploaded ? colors.success : colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isUploading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: _pick,
              child: Text(uploaded ? 'replace'.tr : 'upload'.tr),
            ),
        ],
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
            child: Text(
              ctrl.nameController.text.isEmpty
                  ? 'the_company'.tr
                  : ctrl.nameController.text,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
