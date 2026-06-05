import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../core/shared/input_fields/primary_input.dart';
import '../../../../logic/controller/break/break_controller.dart';

const List<(String, String)> _breakTypes = [
  ('break', 'break_type_break'),
  ('permission', 'break_type_permission'),
  ('prayer', 'break_type_prayer'),
  ('errand', 'break_type_errand'),
  ('medical', 'break_type_medical'),
  ('early_leave', 'break_type_early_leave'),
  ('other', 'break_type_other'),
];

Future<void> showAddBreakSheet(BreakController controller) {
  return Get.bottomSheet<void>(
    AddBreakSheet(controller: controller),
    isScrollControlled: true,
  );
}

class AddBreakSheet extends StatefulWidget {
  final BreakController controller;

  const AddBreakSheet({super.key, required this.controller});

  @override
  State<AddBreakSheet> createState() => _AddBreakSheetState();
}

class _AddBreakSheetState extends State<AddBreakSheet> {
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _startTimeCtrl = TextEditingController();
  final TextEditingController _endTimeCtrl = TextEditingController();

  String _type = 'break';
  bool _submitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _dateCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      _dateCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickTime(TextEditingController ctrl, String hint) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      ctrl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    if (_dateCtrl.text.trim().isEmpty) {
      Get.snackbar('error'.tr, 'break_select_date'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_startTimeCtrl.text.trim().isEmpty) {
      Get.snackbar('error'.tr, 'break_select_start_time'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_endTimeCtrl.text.trim().isEmpty) {
      Get.snackbar('error'.tr, 'break_select_end_time'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _submitting = true);
    final ok = await widget.controller.createBreak(
      date: _dateCtrl.text.trim(),
      startTime: _startTimeCtrl.text.trim(),
      endTime: _endTimeCtrl.text.trim(),
      type: _type,
      reason: _reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Get.back<void>();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(colors),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s2,
                  AppSpacing.s4,
                  AppSpacing.s4 + bottomInset,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('break_type'.tr, colors),
                    const SizedBox(height: AppSpacing.s2),
                    _buildTypePicker(colors),
                    const SizedBox(height: AppSpacing.s4),
                    _sectionLabel('break_date'.tr, colors),
                    const SizedBox(height: AppSpacing.s2),
                    _buildDateField(colors),
                    const SizedBox(height: AppSpacing.s4),
                    _sectionLabel('break_time'.tr, colors),
                    const SizedBox(height: AppSpacing.s2),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeField(colors, _startTimeCtrl, 'break_start_time'.tr),
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: _buildTimeField(colors, _endTimeCtrl, 'break_end_time'.tr),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    PrimaryInput(
                      label: 'break_reason'.tr,
                      controller: _reasonCtrl,
                      hint: 'break_reason'.tr,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.s5),
                    PrimaryButton(
                      text: 'save'.tr,
                      isLoading: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4, AppSpacing.s3, AppSpacing.s2, AppSpacing.s2),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.borderStrong,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('request_break'.tr, style: AppTextStyles.h3(context)),
                    const SizedBox(height: 2),
                    Text('request_break_subtitle'.tr,
                        style: AppTextStyles.sm(context)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Get.back<void>(),
                icon: Icon(Icons.close, color: colors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypePicker(AppColorScheme colors) {
    return Wrap(
      spacing: AppSpacing.s2,
      runSpacing: AppSpacing.s2,
      children: _breakTypes
          .map((t) => _ChoiceChip(
                label: t.$2.tr,
                selected: _type == t.$1,
                onTap: () => setState(() => _type = t.$1),
                colors: colors,
              ))
          .toList(),
    );
  }

  Widget _buildDateField(AppColorScheme colors) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: _fieldDecoration(colors),
        child: Row(
          children: [
            Icon(Icons.event_outlined, size: 20, color: colors.brand),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                _dateCtrl.text.trim().isEmpty
                    ? 'break_select_date'.tr
                    : _dateCtrl.text,
                style: _dateCtrl.text.trim().isEmpty
                    ? AppTextStyles.body(context)
                        .copyWith(color: colors.textTertiary)
                    : const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(
      AppColorScheme colors, TextEditingController ctrl, String hint) {
    return InkWell(
      onTap: () => _pickTime(ctrl, hint),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: _fieldDecoration(colors),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 20, color: colors.brand),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                ctrl.text.trim().isEmpty ? hint.tr : ctrl.text,
                style: ctrl.text.trim().isEmpty
                    ? AppTextStyles.body(context)
                        .copyWith(color: colors.textTertiary)
                    : const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, AppColorScheme colors) {
    return Text(text,
        style: TextStyle(
          fontFamily: 'IBM Plex Sans Arabic',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ));
  }

  BoxDecoration _fieldDecoration(AppColorScheme colors) => BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.borderHairline),
      );
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColorScheme colors;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
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
