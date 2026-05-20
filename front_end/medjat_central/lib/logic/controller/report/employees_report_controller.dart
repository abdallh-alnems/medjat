import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/report_data/report_data.dart';
import '../../../data/model/report_model.dart';

class EmployeesReportController extends GetxController {
  final ReportData _data = Get.find<ReportData>();

  StatusRequest status = StatusRequest.none;
  List<EmployeesReportRow> rows = [];
  EmployeesReportSummary summary = EmployeesReportSummary();
  int? branchFilter;

  @override
  void onInit() {
    super.onInit();
    loadReport();
  }

  Future<void> loadReport() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getEmployeesReport(branchId: branchFilter);

    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is Map) {
        final items = payload['items'];
        if (items is List) {
          rows = items
              .whereType<Map<String, dynamic>>()
              .map(EmployeesReportRow.fromJson)
              .toList();
        }
        if (payload['summary'] is Map) {
          summary = EmployeesReportSummary.fromJson(
              Map<String, dynamic>.from(payload['summary'] as Map));
        }
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  void setBranch(int? branchId) {
    branchFilter = branchId;
    loadReport();
  }
}
