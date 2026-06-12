import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/settings/deduction_rules_controller.dart';
import '../../../data/model/deduction_rule_model.dart';

/// Human label for a day-fraction, e.g. 0.25 → "ربع يوم", 2 → "يومين".
String daysLabel(double d) {
  if (d == 0.25) return 'quarter_day'.tr;
  if (d == 0.5) return 'half_day'.tr;
  if (d == 0.75) return 'three_quarter_day'.tr;
  if (d == 1) return 'one_day'.tr;
  if (d == 2) return 'two_days'.tr;
  final n = d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  return '$n ${'days_unit'.tr}';
}

/// True when, after sorting by threshold, a longer delay deducts strictly less
/// than a shorter one — an illogical (inverted) ladder worth warning about.
bool _hasInvertedTiers(List<LateTier> tiers) {
  for (var i = 1; i < tiers.length; i++) {
    if (tiers[i].deductionDays < tiers[i - 1].deductionDays) return true;
  }
  return false;
}

class DeductionRulesScreen extends StatelessWidget {
  const DeductionRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Resolved from the route binding (not Get.put here): creating the
    // controller inside build() would re-instantiate it on every rebuild and
    // wipe locally-added tiers back to the last saved state.
    final ctrl = Get.find<DeductionRulesController>();
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('deduction_rules'.tr),
        actions: [
          GetBuilder<DeductionRulesController>(
            builder: (_) => ctrl.saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ctrl.loadConfig,
        child: GetBuilder<DeductionRulesController>(
          builder: (_) {
            return HandlingDataRequest(
              statusRequest: ctrl.status,
              onRetry: ctrl.loadConfig,
              widget: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s4,
                  AppSpacing.s4,
                  AppSpacing.s4,
                  AppSpacing.s9,
                ),
                children: [
                  // ── Late tiers ──────────────────────────────
                  _SectionHeader(
                    icon: Icons.schedule_outlined,
                    title: 'late_tiers'.tr,
                    subtitle: 'late_tiers_hint'.tr,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  // #2: empty tiers mean late employees are NOT deducted at all
                  // — warn so admins don't disable late penalties unknowingly.
                  if (ctrl.tiers.isEmpty) ...[
                    _WarningBanner(message: 'no_tiers_warning'.tr),
                    const SizedBox(height: AppSpacing.s2),
                  ]
                  // #3: a longer delay deducting less than a shorter one is
                  // almost certainly a mistake — flag the inverted ladder.
                  else if (_hasInvertedTiers(ctrl.tiers)) ...[
                    _WarningBanner(message: 'tiers_not_monotonic_warning'.tr),
                    const SizedBox(height: AppSpacing.s2),
                  ],
                  if (ctrl.tiers.isEmpty)
                    _EmptyTiers(onAdd: () => _showTierSheet(context, ctrl))
                  else
                    ...ctrl.tiers.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                        child: _TierTile(
                          tier: t,
                          onEdit: () => _showTierSheet(context, ctrl, tier: t),
                          onDelete: () => ctrl.removeTier(t),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.s2),
                  OutlinedButton.icon(
                    onPressed: () => _showTierSheet(context, ctrl),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('add_tier'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.brand,
                      side: BorderSide(color: colors.brand),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s6),

                  // ── Absence ─────────────────────────────────
                  _SectionHeader(
                    icon: Icons.event_busy_outlined,
                    title: 'absence_deduction'.tr,
                    subtitle: 'absence_deduction_hint'.tr,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _AbsenceCard(ctrl: ctrl),

                  const SizedBox(height: AppSpacing.s5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        size: 16,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        'auto_saved_hint'.tr,
                        style: AppTextStyles.sm(context),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showTierSheet(
    BuildContext context,
    DeductionRulesController ctrl, {
    LateTier? tier,
  }) {
    final minutesCtrl = TextEditingController(
      text: tier != null ? tier.thresholdMinutes.toString() : '',
    );
    double selectedDays = tier?.deductionDays ?? 0.25;
    final customDaysCtrl = TextEditingController(
      text: tier != null ? _trimNum(tier.deductionDays) : '',
    );
    const presets = [0.25, 0.5, 1.0, 2.0];
    bool usingCustom = tier != null && !presets.contains(tier.deductionDays);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          final colors = AppColors.of(context);
          // Lift the whole sheet above the keyboard (canonical pattern used by
          // bulk_adjust_sheet) so it sits flush on top of the keyboard with no
          // gap and the deduction chips stay visible while typing.
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
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
                    Text(
                      tier != null ? 'edit_tier'.tr : 'add_tier'.tr,
                      style: AppTextStyles.h3(context),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    PrimaryInput(
                      label: 'late_minutes_threshold'.tr,
                      controller: minutesCtrl,
                      keyboardType: TextInputType.number,
                      hint: '15',
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'deduction_amount_days'.tr,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s2),
                    Wrap(
                      spacing: AppSpacing.s2,
                      runSpacing: AppSpacing.s2,
                      children: [
                        for (final p in presets)
                          _Chip(
                            label: daysLabel(p),
                            selected: !usingCustom && selectedDays == p,
                            onTap: () => setState(() {
                              usingCustom = false;
                              selectedDays = p;
                            }),
                          ),
                        _Chip(
                          label: 'custom'.tr,
                          selected: usingCustom,
                          onTap: () => setState(() => usingCustom = true),
                        ),
                      ],
                    ),
                    if (usingCustom) ...[
                      const SizedBox(height: AppSpacing.s3),
                      PrimaryInput(
                        label: 'days_value'.tr,
                        controller: customDaysCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        hint: '0.5',
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s5),
                    PrimaryButton(
                      text: tier != null ? 'update'.tr : 'add'.tr,
                      onPressed: () {
                        final minutes =
                            int.tryParse(minutesCtrl.text.trim()) ?? 0;
                        final days = usingCustom
                            ? (double.tryParse(customDaysCtrl.text.trim()) ?? 0)
                            : selectedDays;
                        if (minutes <= 0) {
                          Get.snackbar(
                            'error'.tr,
                            'invalid_minutes'.tr,
                            snackPosition: SnackPosition.BOTTOM,
                          );
                          return;
                        }
                        if (days <= 0) {
                          Get.snackbar(
                            'error'.tr,
                            'invalid_days'.tr,
                            snackPosition: SnackPosition.BOTTOM,
                          );
                          return;
                        }
                        final err = ctrl.upsertTier(
                          LateTier(
                            id: tier?.id,
                            thresholdMinutes: minutes,
                            deductionDays: days,
                          ),
                          replacing: tier,
                        );
                        if (err != null) {
                          Get.snackbar(
                            'error'.tr,
                            'tier_duplicate_msg'.tr,
                            snackPosition: SnackPosition.BOTTOM,
                          );
                          return;
                        }
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _trimNum(double d) =>
      d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.brand),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h3(context)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTextStyles.bodySecondary(context)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyTiers extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTiers({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s5),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        children: [
          Icon(Icons.timer_off_outlined, size: 36, color: colors.textTertiary),
          const SizedBox(height: AppSpacing.s2),
          Text('no_tiers'.tr, style: AppTextStyles.bodySecondary(context)),
        ],
      ),
    );
  }
}

class _TierTile extends StatelessWidget {
  final LateTier tier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TierTile({
    required this.tier,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s2,
            ),
            decoration: BoxDecoration(
              color: colors.brandSubtle,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '${tier.thresholdMinutes} ${'minute_unit'.tr}',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.brand,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
            child: Icon(
              Icons.arrow_forward,
              size: 16,
              color: colors.textTertiary,
            ),
          ),
          Expanded(
            child: Text(
              '${'deduct'.tr} ${daysLabel(tier.deductionDays)}',
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.edit_outlined,
              size: 20,
              color: colors.textSecondary,
            ),
            onPressed: onEdit,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline, size: 20, color: colors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AbsenceCard extends StatelessWidget {
  final DeductionRulesController ctrl;
  const _AbsenceCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final controller = TextEditingController(
      text: ctrl.absenceDays == ctrl.absenceDays.roundToDouble()
          ? ctrl.absenceDays.toStringAsFixed(0)
          : ctrl.absenceDays.toString(),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'absence_days_per_day'.tr,
              style: AppTextStyles.body(context),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          SizedBox(
            width: 90,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                suffixText: 'days_unit'.tr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              onChanged: (v) =>
                  ctrl.setAbsenceDays(double.tryParse(v.trim()) ?? 0),
              onTapOutside: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
                ctrl.persistAbsence(
                  double.tryParse(controller.text.trim()) ?? 0,
                );
              },
              onSubmitted: (v) =>
                  ctrl.persistAbsence(double.tryParse(v.trim()) ?? 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: colors.warning),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12.5,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
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
