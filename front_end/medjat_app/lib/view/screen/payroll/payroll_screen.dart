import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/handling_data_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import '../../../../logic/controller/payroll/payroll_controller.dart';

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

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
            onPressed: () {
              final current = DateTime.parse('${controller.selectedMonth}-01');
              final next = DateTime(current.year, current.month + 1);
              controller.changeMonth(
                '${next.year}-${next.month.toString().padLeft(2, '0')}',
              );
            },
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _slipRow(context, 'base_salary'.tr, slip['base_salary']?.toString() ?? '0'),
          if (slip['allowances'] != null)
            _slipRow(context, 'allowances'.tr, slip['allowances']?.toString() ?? '0'),
          if (slip['overtime_amount'] != null)
            _slipRow(context, 'overtime'.tr, slip['overtime_amount']?.toString() ?? '0'),
          if (slip['deductions'] != null)
            _slipRow(context, 'deductions'.tr, slip['deductions']?.toString() ?? '0',
                valueColor: Colors.red),
          const Divider(height: 32),
          _slipRow(
            context,
            'net'.tr,
            slip['net_salary']?.toString() ?? slip['total']?.toString() ?? '0',
            isBold: true,
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

  Widget _slipRow(BuildContext context, String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: isBold ? AppTextStyles.h3(context) : AppTextStyles.body(context)),
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
}
