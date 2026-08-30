import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/report_data/report_data.dart';
import '../../../data/model/report_model.dart';

class PayrollReportController extends GetxController {
  final ReportData _data = Get.find<ReportData>();

  StatusRequest status = StatusRequest.none;
  List<PayrollReportRow> rows = [];
  PayrollReportSummary summary = PayrollReportSummary();
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  int? branchFilter;

  @override
  void onInit() {
    super.onInit();
    loadReport();
  }

  String get _monthStr =>
      '$selectedYear-${selectedMonth.toString().padLeft(2, '0')}';

  Future<void> loadReport() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getPayrollReport(
      month: _monthStr,
      branchId: branchFilter,
    );

    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is Map) {
        final items = payload['items'];
        if (items is List) {
          rows = items
              .whereType<Map<String, dynamic>>()
              .map(PayrollReportRow.fromJson)
              .toList();
        }
        if (payload['summary'] is Map) {
          summary = PayrollReportSummary.fromJson(
              Map<String, dynamic>.from(payload['summary'] as Map));
        }
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  void changeMonth(int month, int year) {
    selectedMonth = month;
    selectedYear = year;
    loadReport();
  }

  void setBranch(int? branchId) {
    branchFilter = branchId;
    loadReport();
  }
}
