import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/report_data/report_data.dart';
import '../../../data/model/report_model.dart';

class AttendanceReportController extends GetxController {
  final ReportData _data = Get.find<ReportData>();

  StatusRequest status = StatusRequest.none;
  List<AttendanceReportRow> rows = [];
  AttendanceReportSummary summary = AttendanceReportSummary();
  DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime endDate = DateTime.now();
  int? branchFilter;

  @override
  void onInit() {
    super.onInit();
    loadReport();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> loadReport() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getAttendanceReport(
      startDate: _fmt(startDate),
      endDate: _fmt(endDate),
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
              .map(AttendanceReportRow.fromJson)
              .toList();
        }
        if (payload['summary'] is Map) {
          summary = AttendanceReportSummary.fromJson(
              Map<String, dynamic>.from(payload['summary'] as Map));
        }
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  void setDateRange(DateTime start, DateTime end) {
    startDate = start;
    endDate = end;
    loadReport();
  }

  void setBranch(int? branchId) {
    branchFilter = branchId;
    loadReport();
  }
}
