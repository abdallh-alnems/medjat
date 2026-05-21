import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/expense/expense_controller.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/expense_claim_model.dart';
import '../../../data/model/employee_model.dart';

const _expenseCategories = [
  'travel',
  'meals',
  'accommodation',
  'supplies',
  'medical',
  'communication',
  'other',
];

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put<ExpenseController>(ExpenseController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('expenses'.tr)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_expense',
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
                  label: 'status_pending'.tr,
                  selected: ctrl.statusFilter == 'pending',
                  onTap: () => ctrl.filterByStatus('pending'),
                ),
                const SizedBox(width: AppSpacing.s2),
                _Chip(
                  label: 'status_approved'.tr,
                  selected: ctrl.statusFilter == 'approved',
                  onTap: () => ctrl.filterByStatus('approved'),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadExpenses,
              child: GetBuilder<ExpenseController>(
                builder: (_) {
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadExpenses,
                    widget: ctrl.expenses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 48, color: colors.textTertiary),
                                const SizedBox(height: AppSpacing.s3),
                                Text('no_expenses'.tr,
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
                            itemCount: ctrl.expenses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s2),
                            itemBuilder: (_, i) => _ExpenseTile(
                              expense: ctrl.expenses[i],
                              onApprove: () => ctrl.approve(ctrl.expenses[i].id),
                              onReject: () => _showRejectDialog(
                                  context, ctrl, ctrl.expenses[i].id),
                              onReimburse: () =>
                                  ctrl.reimburse(ctrl.expenses[i].id),
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

  void _showRejectDialog(
      BuildContext context, ExpenseController ctrl, int id) {
    final reasonCtrl = TextEditingController();
    final colors = AppColors.of(context);

    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('expense_reject'.tr,
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
                ctrl.reject(id,
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

  void _showCreateSheet(BuildContext context, ExpenseController ctrl) {
    final descCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    int? selectedEmployeeId;
    String selectedCategory = 'other';
    DateTime? expenseDate;

    final employeeData = Get.find<EmployeeData>();

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setSheetState) {
          final colors = AppColors.of(context);
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
                  Text('expense_add'.tr, style: AppTextStyles.h3(context)),
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
                  _label('expense_category'.tr, colors),
                  const SizedBox(height: AppSpacing.s2),
                  Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: _expenseCategories
                        .map((c) => _Chip(
                              label: 'expense_cat_$c'.tr,
                              selected: selectedCategory == c,
                              onTap: () =>
                                  setSheetState(() => selectedCategory = c),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'expense_amount'.tr,
                    controller: amountCtrl,
                    hint: 'expense_amount'.tr,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _DatePickerField(
                    label: 'expense_date'.tr,
                    value: expenseDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expenseDate ?? DateTime.now(),
                        firstDate: DateTime(2023, 1, 1),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setSheetState(() => expenseDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'expense_description'.tr,
                    controller: descCtrl,
                    hint: 'expense_description'.tr,
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  PrimaryButton(
                    text: 'save'.tr,
                    onPressed: () async {
                      final amount =
                          double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (selectedEmployeeId == null) {
                        Get.snackbar('error'.tr, 'select_employee'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      if (amount <= 0) {
                        Get.snackbar('error'.tr, 'expense_amount_invalid'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      if (expenseDate == null) {
                        Get.snackbar('error'.tr, 'expense_date'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      final ok = await ctrl.createExpense(
                        employeeId: selectedEmployeeId!,
                        category: selectedCategory,
                        amount: amount,
                        expenseDate: expenseDate!,
                        description: descCtrl.text,
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

class _ExpenseTile extends StatelessWidget {
  final ExpenseClaimModel expense;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onReimburse;

  const _ExpenseTile({
    required this.expense,
    required this.onApprove,
    required this.onReject,
    required this.onReimburse,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(expense.status, colors);

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
                  expense.employeeName ?? 'employee'.tr,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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
                  expense.statusLabel,
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
              Text(
                expense.categoryLabel,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '${expense.amount.toStringAsFixed(2)} ${expense.currency}',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s1),
          Text(
            '${expense.expenseDate.year}-${expense.expenseDate.month.toString().padLeft(2, '0')}-${expense.expenseDate.day.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12,
              color: colors.textTertiary,
            ),
          ),
          if (expense.description != null &&
              expense.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(expense.description!, style: AppTextStyles.sm(context)),
          ],
          if (expense.status == 'rejected' &&
              expense.rejectionReason != null &&
              expense.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Row(
              children: [
                Icon(Icons.block, size: 14, color: colors.error),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: Text(
                    expense.rejectionReason!,
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
          if (expense.status == 'pending') ...[
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onApprove,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: Text('accept'.tr),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: TextButton(
                    onPressed: onReject,
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
          if (expense.status == 'approved') ...[
            const SizedBox(height: AppSpacing.s3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReimburse,
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: Text('expense_mark_reimbursed'.tr),
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
      case 'pending':
        return colors.warning;
      case 'approved':
        return colors.success;
      case 'reimbursed':
        return colors.brand;
      case 'rejected':
        return colors.error;
      default:
        return colors.textTertiary;
    }
  }
}
