import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/report_data/report_data.dart';
import '../../../data/model/report_model.dart';

/// Drives the overtime & lateness report: per-employee totals for a period,
/// plus the day-by-day drill-down behind a single row.
class OvertimeLateReportController extends GetxController {
  final ReportData _data = Get.find<ReportData>();

  StatusRequest status = StatusRequest.none;
  List<OvertimeLateRow> rows = [];
  OvertimeLateSummary summary = OvertimeLateSummary();

  DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime endDate = DateTime.now();
  int? branchFilter;

  /// Server-side ordering: 'overtime' | 'late' | 'name'.
  String sort = 'overtime';

  // ── Drill-down (one employee's days) ──
  StatusRequest daysStatus = StatusRequest.none;
  List<OvertimeLateDay> days = [];

  @override
  void onInit() {
    super.onInit();
    loadReport();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get periodLabel => '${_fmt(startDate)} — ${_fmt(endDate)}';

  Future<void> loadReport() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getOvertimeLateReport(
      startDate: _fmt(startDate),
      endDate: _fmt(endDate),
      branchId: branchFilter,
      sort: sort,
    );

    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is Map) {
        final items = payload['items'];
        rows = items is List
            ? items
                .whereType<Map<String, dynamic>>()
                .map(OvertimeLateRow.fromJson)
                .toList()
            : <OvertimeLateRow>[];
        summary = payload['summary'] is Map
            ? OvertimeLateSummary.fromJson(
                Map<String, dynamic>.from(payload['summary'] as Map))
            : OvertimeLateSummary();
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  /// Loads the days behind one employee's totals for the open bottom sheet.
  Future<void> loadDays(int employeeId) async {
    days = [];
    daysStatus = StatusRequest.loading;
    update(['days']);

    final response = await _data.getOvertimeLateReport(
      startDate: _fmt(startDate),
      endDate: _fmt(endDate),
      employeeId: employeeId,
      sort: sort,
    );

    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is Map && payload['days'] is List) {
        days = (payload['days'] as List)
            .whereType<Map<String, dynamic>>()
            .map(OvertimeLateDay.fromJson)
            .toList();
      }
      daysStatus = StatusRequest.success;
    } else {
      daysStatus = StatusRequest.failure;
    }
    update(['days']);
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

  void setSort(String value) {
    if (sort == value) return;
    sort = value;
    loadReport();
  }
}
