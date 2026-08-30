import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../logic/controller/advance/advance_controller.dart';

class AdvanceApplyForm extends StatelessWidget {
  final AdvanceController controller;

  const AdvanceApplyForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final amountController = TextEditingController();
    final installmentsController = TextEditingController(text: '1');
    final reasonController = TextEditingController();
    DateTime startMonth =
        DateTime(DateTime.now().year, DateTime.now().month);

    String fmtMonth(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}';
    String labelMonth(DateTime d) => '${_monthKeys[d.month - 1].tr} ${d.year}';

    return StatefulBuilder(
      builder: (context, setState) {
        final colors = AppColors.of(context);
        final total = double.tryParse(amountController.text.trim()) ?? 0;
        final count = int.tryParse(installmentsController.text.trim()) ?? 0;
        final perInstallment = count > 0 ? total / count : 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('request_advance'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'advance_amount'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: installmentsController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'advance_installments_count'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () async {
                final picked = await _pickMonth(context, startMonth);
                if (picked != null) {
                  setState(() => startMonth = picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'advance_start_month'.tr,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(labelMonth(startMonth),
                    style: AppTextStyles.body(context)),
              ),
            ),
            if (count > 0 && total > 0) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border:
                      Border.all(color: colors.brand.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: colors.brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'advance_installment_preview'.trParams({
                          'amount': perInstallment.toStringAsFixed(0),
                          'count': count.toString(),
                        }),
                        style: AppTextStyles.sm(context)
                            .copyWith(color: colors.brand),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'reason_optional'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            GetBuilder<AdvanceController>(
              builder: (ctrl) {
                if (!ctrl.canRequest) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: colors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: colors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('advance_pending_limit_msg'.tr,
                              style: AppTextStyles.sm(context)),
                        ),
                      ],
                    ),
                  );
                }
                return PrimaryButton(
                  text: 'submit_request'.tr,
                  isLoading: ctrl.requestStatus == StatusRequest.loading,
                  onPressed: () async {
                    final amount =
                        double.tryParse(amountController.text.trim()) ?? 0;
                    final installments =
                        int.tryParse(installmentsController.text.trim()) ?? 0;
                    if (amount <= 0) {
                      Get.snackbar('error'.tr, 'advance_amount_invalid'.tr,
                          snackPosition: SnackPosition.BOTTOM);
                      return;
                    }
                    if (installments < 1) {
                      Get.snackbar(
                          'error'.tr, 'advance_installments_invalid'.tr,
                          snackPosition: SnackPosition.BOTTOM);
                      return;
                    }
                    final ok = await ctrl.requestAdvance(
                      totalAmount: amount,
                      installmentsCount: installments,
                      startMonth: fmtMonth(startMonth),
                      reason: reasonController.text.isEmpty
                          ? null
                          : reasonController.text,
                    );
                    if (ok) {
                      amountController.clear();
                      installmentsController.text = '1';
                      reasonController.clear();
                      setState(() {
                        startMonth = DateTime(
                            DateTime.now().year, DateTime.now().month);
                      });
                    }
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

const List<String> _monthKeys = [
  'january', 'february', 'march', 'april', 'may', 'june',
  'july', 'august', 'september', 'october', 'november', 'december',
];

/// Month/year picker — the deduction field only needs a month, the day is
/// meaningless here, so we show a year stepper with a 12-month grid instead of
/// a full calendar. Months earlier than the current one are disabled.
Future<DateTime?> _pickMonth(BuildContext context, DateTime initial) {
  final now = DateTime(DateTime.now().year, DateTime.now().month);
  int year = initial.year;

  return Get.dialog<DateTime>(
    Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (context, setState) {
          final colors = AppColors.of(context);
          return AlertDialog(
            title: Text('advance_start_month'.tr,
                style: AppTextStyles.h3(context)),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: year > now.year
                            ? () => setState(() => year--)
                            : null,
                      ),
                      Text('$year',
                          style: AppTextStyles.body(context)
                              .copyWith(fontWeight: FontWeight.w600)),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: year < now.year + 2
                            ? () => setState(() => year++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                    children: List.generate(12, (i) {
                      final m = i + 1;
                      final disabled = year == now.year && m < now.month;
                      final highlight =
                          year == initial.year && m == initial.month;
                      return _MonthCell(
                        label: _monthKeys[i].tr,
                        disabled: disabled,
                        highlight: highlight,
                        colors: colors,
                        onTap: disabled
                            ? null
                            : () =>
                                Get.back<DateTime>(result: DateTime(year, m)),
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back<DateTime>(),
                child: Text('cancel'.tr),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _MonthCell extends StatelessWidget {
  final String label;
  final bool disabled;
  final bool highlight;
  final AppColorScheme colors;
  final VoidCallback? onTap;

  const _MonthCell({
    required this.label,
    required this.disabled,
    required this.highlight,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: highlight
              ? colors.brand.withValues(alpha: 0.12)
              : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: highlight ? colors.brand : colors.borderHairline,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.sm(context).copyWith(
            color: disabled
                ? colors.borderHairline
                : (highlight ? colors.brand : null),
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
