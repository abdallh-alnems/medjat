import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';
import '../../../data/model/payroll_model.dart';
import '../../../logic/controller/auth/auth_controller.dart';

class PayrollController extends GetxController {
  final PayrollData _payrollData = Get.find<PayrollData>();

  StatusRequest status = StatusRequest.none;
  List<PayrollModel> payrolls = [];
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  int? branchFilter;

  bool get canManagePayroll {
    try {
      final auth = Get.find<AuthController>();
      return auth.user?.canManagePayroll ?? false;
    } catch (_) {
      return false;
    }
  }

  bool get hasApprovedPayrolls =>
      payrolls.any((p) => p.status == 'approved');

  @override
  void onInit() {
    super.onInit();
    loadPayrolls();
  }

  Future<void> loadPayrolls() async {
    status = StatusRequest.loading;
    update();

    final response = await _payrollData.getPayrollMonth(
      selectedMonth,
      selectedYear,
      branchId: branchFilter,
    );

    if (response['status'] == StatusRequest.success) {
      payrolls = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  List<PayrollModel> _extractItems(dynamic raw) {
    dynamic payload = raw;
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
    if (items == null) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PayrollModel.fromJson)
        .toList();
  }

  void changeMonth(int month, int year) {
    selectedMonth = month;
    selectedYear = year;
    loadPayrolls();
  }

  Future<void> approvePayroll(int id) async {
    final response = await _payrollData.approvePayroll(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'payroll_approved'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadPayrolls();
    } else {
      Get.snackbar('error'.tr, 'payroll_approve_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<Map<String, dynamic>?> getBankFilePreview() async {
    final monthStr =
        '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}';
    final response =
        await _payrollData.getBankFilePreview(monthStr, branchId: branchFilter);
    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map<String, dynamic>) {
        return data;
      }
    }
    return null;
  }

  Future<String?> downloadBankFile() async {
    final monthStr =
        '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}';
    return await _payrollData.downloadBankFile(monthStr, branchId: branchFilter);
  }

  void showBankFileDialog(BuildContext context) async {
    final preview = await getBankFilePreview();
    if (preview == null) {
      Get.snackbar('error'.tr, 'failed_load_preview'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => _BankFilePreviewDialog(
        preview: preview,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          Get.snackbar('exporting'.tr, '',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 2));
          final path = await downloadBankFile();
          if (path != null) {
            Get.snackbar(
              'done'.tr,
              '${'file_saved_to'.tr} $path',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 5),
            );
          } else {
            Get.snackbar('error'.tr, 'export_failed'.tr,
                snackPosition: SnackPosition.BOTTOM);
          }
        },
      ),
    );
  }
}

class _BankFilePreviewDialog extends StatelessWidget {
  final Map<String, dynamic> preview;
  final VoidCallback onConfirm;

  const _BankFilePreviewDialog({
    required this.preview,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final missing = (preview['missing'] as List?) ?? [];

    return AlertDialog(
      title: Text('bank_file_preview'.tr,
          style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('month'.tr, preview['month']?.toString() ?? ''),
            _row('total_employees'.tr,
                preview['total_employees']?.toString() ?? '0'),
            _row('ready_count'.tr,
                preview['ready_count']?.toString() ?? '0'),
            _row('total_amount'.tr,
                '${(preview['total_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'} ${'currency_egp'.tr}'),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${'missing_bank_info'.tr} (${missing.length})',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...missing.map((m) => Text(
                          '• ${m['name']}',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 12,
                            color: colors.error,
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('cancel'.tr),
        ),
        ElevatedButton(
          onPressed: preview['ready_count'] != 0 ? onConfirm : null,
          child: Text('confirm_export'.tr),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
