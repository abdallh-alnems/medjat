import 'dart:io';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';

class PayrollController extends GetxController {
  final PayrollData _payrollData = Get.find<PayrollData>();

  StatusRequest status = StatusRequest.none;
  Map<String, dynamic>? slipData;
  String selectedMonth = '';

  /// The current calendar month in `YYYY-MM` format.
  String get _currentMonth {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Whether the employee can move forward a month. Future months haven't
  /// happened yet, so navigating past the current month is not allowed.
  bool get canGoNext => selectedMonth.compareTo(_currentMonth) < 0;

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    selectedMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    loadSlip(selectedMonth);
  }

  void changeMonth(String month) {
    selectedMonth = month;
    loadSlip(month);
  }

  Future<void> loadSlip(String month) async {
    status = StatusRequest.loading;
    update();

    final response = await _payrollData.getSlip(month);
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      slipData = response['data'] as Map<String, dynamic>?;
      status = StatusRequest.success;
    } else if (response['statusCode'] == 404) {
      // No payroll slip generated for this month yet — show the friendly
      // "no slip this month" empty state instead of the generic error screen.
      slipData = null;
      status = StatusRequest.success;
    } else if (responseStatus == StatusRequest.offline) {
      status = StatusRequest.offline;
    } else {
      status = StatusRequest.failure;
    }

    update();
  }

  Future<void> downloadPdf() async {
    final response = await _payrollData.getSlipPdf(selectedMonth);
    if (response['status'] == StatusRequest.success &&
        response['bytes'] != null) {
      try {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/payroll_$selectedMonth.pdf');
        await file.writeAsBytes(response['bytes'] as List<int>);
        await OpenFilex.open(file.path);
      } catch (e) {
        Get.snackbar('error'.tr, 'failed_save_file'.tr);
      }
    } else {
      Get.snackbar('error'.tr, 'failed_download_slip'.tr);
    }
  }
}
