import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/handling_data_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../logic/controller/payroll/payroll_controller.dart';

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => PayrollController());
    return Scaffold(
      appBar: AppBar(title: Text('my_salary'.tr)),
      body: GetBuilder<PayrollController>(
        builder: (controller) {
          return Column(
            children: [
              _monthSelector(context, controller),
              Expanded(
                child: HandlingDataRequest(
                  statusRequest: controller.status,
                  widget: _buildSlip(context, controller),
                  onRetry: () => controller.loadSlip(controller.selectedMonth),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _monthSelector(BuildContext context, PayrollController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {
              final current = DateTime.parse('${controller.selectedMonth}-01');
              final prev = DateTime(current.year, current.month - 1);
              controller.changeMonth(
                '${prev.year}-${prev.month.toString().padLeft(2, '0')}',
              );
            },
            icon: const Icon(Icons.chevron_right),
          ),
          Text(controller.selectedMonth, style: AppTextStyles.h3(context)),
          IconButton(
            // Future months haven't happened yet — disable forward navigation
            // once the current month is reached.
            onPressed: controller.canGoNext
                ? () {
                    final current =
                        DateTime.parse('${controller.selectedMonth}-01');
                    final next = DateTime(current.year, current.month + 1);
                    controller.changeMonth(
                      '${next.year}-${next.month.toString().padLeft(2, '0')}',
                    );
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
        ],
      ),
    );
  }

  Widget _buildSlip(BuildContext context, PayrollController controller) {
    final slip = controller.slipData;
    if (slip == null) {
      return Center(
        child: Text('no_slip_month'.tr, style: AppTextStyles.bodySecondary(context)),
      );
    }

    final deductions = _lines(slip['deductions_breakdown']);
    final additions = _lines(slip['bonuses_breakdown']);
    final status = slip['status']?.toString() ?? 'draft';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusBanner(context, status, slip['paid_at']),

          // ---- Summary ----
          _sectionCard(
            context,
            title: 'salary_summary'.tr,
            children: [
              _slipRow(context, 'base_salary'.tr, _money(slip['base_salary'])),
              _slipRow(context, 'total_additions'.tr,
                  '+ ${_money(slip['total_bonuses'])}',
                  valueColor: _green),
              _slipRow(context, 'total_deductions'.tr,
                  '- ${_money(slip['total_deductions'])}',
                  valueColor: Colors.red),
              const Divider(height: 28),
              _slipRow(context, 'net'.tr, _money(slip['net_salary']),
                  isBold: true),
            ],
          ),

          // ---- Additions detail ----
          const SizedBox(height: 16),
          _sectionCard(
            context,
            title: 'additions_details'.tr,
            children: additions.isEmpty
                ? [_emptyRow(context, 'no_additions'.tr)]
                : additions
                    .map((d) => _detailRow(context, d, _green, '+'))
                    .toList(),
          ),

          // ---- Deductions detail ----
          const SizedBox(height: 16),
          _sectionCard(
            context,
            title: 'deductions_details'.tr,
            children: deductions.isEmpty
                ? [_emptyRow(context, 'no_deductions'.tr)]
                : deductions
                    .map((d) => _detailRow(context, d, Colors.red, '-'))
                    .toList(),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => controller.downloadPdf(),
              icon: const Icon(Icons.download),
              label: Text('download_pdf'.tr),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A status banner shown above the slip details. It always tells the
  /// employee whether the salary has been deposited yet ("لم ينزل بعد") or
  /// already paid, while the full breakdown stays visible below.
  Widget _statusBanner(BuildContext context, String status, dynamic paidAt) {
    final Color color;
    final IconData icon;
    final String label;
    final String? sub;

    switch (status) {
      case 'paid':
        color = _green;
        icon = Icons.check_circle;
        label = 'salary_paid'.tr;
        final date = paidAt?.toString().split(' ').first ?? '';
        sub = date.isNotEmpty ? '${'paid_on'.tr} $date' : null;
        break;
      case 'approved':
        color = const Color(0xFF1565C0);
        icon = Icons.verified;
        label = 'salary_not_paid'.tr;
        sub = 'salary_approved_awaiting'.tr;
        break;
      default: // draft
        color = Colors.orange;
        icon = Icons.schedule;
        label = 'salary_not_paid'.tr;
        sub = 'payroll_draft_note'.tr;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body(context)
                      .copyWith(color: color, fontWeight: FontWeight.w700),
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(sub, style: AppTextStyles.bodySecondary(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context,
      {required String title, required List<Widget> children}) {
    final scheme = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3(context)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  /// One detailed line from the breakdown: the Arabic description from the
  /// backend plus its signed amount.
  Widget _detailRow(BuildContext context, Map<String, dynamic> line,
      Color color, String sign) {
    final label = (line['description']?.toString().trim().isNotEmpty ?? false)
        ? line['description'].toString()
        : (line['type']?.toString() ?? '');
    return _slipRow(context, label, '$sign ${_money(line['amount'])}',
        valueColor: color);
  }

  Widget _emptyRow(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: AppTextStyles.bodySecondary(context)),
    );
  }

  Widget _slipRow(BuildContext context, String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: isBold
                    ? AppTextStyles.h3(context)
                    : AppTextStyles.body(context)),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 18 : 15,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Normalises a breakdown field (List of line maps) coming from the API.
  List<Map<String, dynamic>> _lines(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return [];
  }

  /// Formats a money value, trimming a trailing ".00".
  String _money(dynamic v) {
    final n = v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;
    final s = n.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }
}
