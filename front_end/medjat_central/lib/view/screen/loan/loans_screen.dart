import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/loan/loan_controller.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/loan_model.dart';
import '../../../data/model/employee_model.dart';

class LoansScreen extends StatelessWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put<LoanController>(LoanController());
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('loans'.tr)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_loan',
        onPressed: () => _showCreateSheet(context, ctrl),
        backgroundColor: colors.brand,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // Wrapped in GetBuilder so the chips' selected state tracks the
          // active filter; otherwise the highlight stays stuck on "all".
          GetBuilder<LoanController>(
            builder: (ctrl) => Padding(
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
                    label: 'loan_active'.tr,
                    selected: ctrl.statusFilter == 'active',
                    onTap: () => ctrl.filterByStatus('active'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadLoans,
              child: GetBuilder<LoanController>(
                builder: (_) {
                  return HandlingDataRequest(
                    statusRequest: ctrl.status,
                    onRetry: ctrl.loadLoans,
                    widget: ctrl.loans.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_wallet_outlined,
                                    size: 48, color: colors.textTertiary),
                                const SizedBox(height: AppSpacing.s3),
                                Text('no_loans'.tr,
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
                            itemCount: ctrl.loans.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s2),
                            itemBuilder: (_, i) => _LoanTile(
                              loan: ctrl.loans[i],
                              onApprove: () => ctrl.approve(ctrl.loans[i].id),
                              onCancel: () =>
                                  _confirmCancel(context, ctrl, ctrl.loans[i].id),
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

  void _confirmCancel(BuildContext context, LoanController ctrl, int id) {
    final colors = AppColors.of(context);
    Get.dialog<void>(
      Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('loan_cancel'.tr,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
          content: Text('loan_cancel_confirm'.tr,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
              )),
          actions: [
            TextButton(
              onPressed: () => Get.back<void>(),
              child: Text('cancel'.tr),
            ),
            TextButton(
              onPressed: () {
                Get.back<void>();
                ctrl.cancel(id);
              },
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text('loan_cancel'.tr),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, LoanController ctrl) {
    final amountCtrl = TextEditingController();
    final installmentsCtrl = TextEditingController(text: '1');
    final reasonCtrl = TextEditingController();
    int? selectedEmployeeId;
    const selectedType = 'advance';
    DateTime startMonth = DateTime(DateTime.now().year, DateTime.now().month);

    final employeeData = Get.find<EmployeeData>();

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setSheetState) {
          final colors = AppColors.of(context);
          final total = double.tryParse(amountCtrl.text.trim()) ?? 0;
          final count = int.tryParse(installmentsCtrl.text.trim()) ?? 0;
          final perInstallment =
              count > 0 ? (total / count) : 0;

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
                  Text('loan_add'.tr, style: AppTextStyles.h3(context)),
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
                  PrimaryInput(
                    label: 'loan_total_amount'.tr,
                    controller: amountCtrl,
                    hint: 'loan_total_amount'.tr,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'loan_installments_count'.tr,
                    controller: installmentsCtrl,
                    hint: 'loan_installments_count'.tr,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _label('loan_start_month'.tr, colors),
                  const SizedBox(height: AppSpacing.s2),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startMonth,
                        firstDate: DateTime(2024, 1, 1),
                        lastDate: DateTime(2030, 12, 31),
                      );
                      if (picked != null) {
                        setSheetState(() =>
                            startMonth = DateTime(picked.year, picked.month));
                      }
                    },
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
                            _fmtMonth(startMonth),
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (count > 0 && total > 0) ...[
                    const SizedBox(height: AppSpacing.s3),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s3),
                      decoration: BoxDecoration(
                        color: colors.brandSubtle,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: colors.brand),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: colors.brand),
                          const SizedBox(width: AppSpacing.s2),
                          Expanded(
                            child: Text(
                              'loan_installment_preview'.trParams({
                                'amount': perInstallment.toStringAsFixed(0),
                                'count': count.toString(),
                              }),
                              style: TextStyle(
                                fontFamily: 'IBM Plex Sans Arabic',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.brand,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s3),
                  PrimaryInput(
                    label: 'loan_reason'.tr,
                    controller: reasonCtrl,
                    hint: 'loan_reason'.tr,
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
                      if (total <= 0) {
                        Get.snackbar('error'.tr, 'loan_amount_invalid'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      if (count < 1) {
                        Get.snackbar('error'.tr, 'loan_installments_invalid'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                        return;
                      }
                      final ok = await ctrl.createLoan(
                        employeeId: selectedEmployeeId!,
                        type: selectedType,
                        totalAmount: total,
                        installmentsCount: count,
                        startMonth: _fmtMonth(startMonth),
                        reason: reasonCtrl.text,
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

String _fmtMonth(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

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

class _LoanTile extends StatelessWidget {
  final LoanModel loan;
  final VoidCallback onApprove;
  final VoidCallback onCancel;

  const _LoanTile({
    required this.loan,
    required this.onApprove,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(loan.status, colors);

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
                  loan.employeeName ?? 'employee'.tr,
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
                  loan.statusLabel,
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
                loan.typeLabel,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                loan.totalAmount.toStringAsFixed(0),
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'loan_installment_line'.trParams({
              'amount': loan.installmentAmount.toStringAsFixed(0),
              'count': loan.installmentsCount.toString(),
            }),
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              color: colors.textTertiary,
            ),
          ),
          if (loan.status == 'active' || loan.status == 'completed') ...[
            const SizedBox(height: AppSpacing.s2),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: loan.progress,
                minHeight: 6,
                backgroundColor: colors.sunken,
                valueColor: AlwaysStoppedAnimation<Color>(colors.brand),
              ),
            ),
            const SizedBox(height: AppSpacing.s1),
            Text(
              'loan_progress_line'.trParams({
                'paid': loan.installmentsPaid.toString(),
                'total': loan.installmentsCount.toString(),
                'remaining': loan.remainingAmount.toStringAsFixed(0),
              }),
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
          if (loan.reason != null && loan.reason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(loan.reason!, style: AppTextStyles.sm(context)),
          ],
          if (loan.status == 'pending') ...[
            const SizedBox(height: AppSpacing.s3),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onApprove,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: Text('loan_approve_btn'.tr),
                  ),
                ),
                const SizedBox(width: AppSpacing.s2),
                Expanded(
                  child: TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.error,
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: Text('loan_cancel'.tr),
                  ),
                ),
              ],
            ),
          ] else if (loan.status == 'active') ...[
            const SizedBox(height: AppSpacing.s3),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: colors.error,
                  minimumSize: const Size.fromHeight(40),
                ),
                child: Text('loan_cancel'.tr),
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
      case 'active':
        return colors.brand;
      case 'completed':
        return colors.success;
      case 'cancelled':
        return colors.textTertiary;
      case 'rejected':
        return colors.error;
      default:
        return colors.textTertiary;
    }
  }
}
