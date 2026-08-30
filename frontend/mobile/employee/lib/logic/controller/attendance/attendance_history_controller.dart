import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';

/// Drives the employee's read-only attendance history screen: loads the
/// records for a selected `YYYY-MM` month and exposes simple month navigation
/// plus aggregate totals for the summary header.
class AttendanceHistoryController extends GetxController {
  final AttendanceData _attendanceData = Get.find<AttendanceData>();

  StatusRequest status = StatusRequest.none;
  List<Map<String, dynamic>> records = [];
  String selectedMonth = '';

  /// The current calendar month in `YYYY-MM` format.
  String get _currentMonth {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Future months haven't happened yet, so forward navigation stops at the
  /// current month.
  bool get canGoNext => selectedMonth.compareTo(_currentMonth) < 0;

  @override
  void onInit() {
    super.onInit();
    selectedMonth = _currentMonth;
    loadMonth(selectedMonth);
  }

  void changeMonth(String month) {
    selectedMonth = month;
    loadMonth(month);
  }

  void goPrevMonth() {
    final current = DateTime.parse('$selectedMonth-01');
    final prev = DateTime(current.year, current.month - 1);
    changeMonth('${prev.year}-${prev.month.toString().padLeft(2, '0')}');
  }

  void goNextMonth() {
    if (!canGoNext) return;
    final current = DateTime.parse('$selectedMonth-01');
    final next = DateTime(current.year, current.month + 1);
    changeMonth('${next.year}-${next.month.toString().padLeft(2, '0')}');
  }

  Future<void> loadMonth(String month) async {
    status = StatusRequest.loading;
    update();

    final response = await _attendanceData.getMyAttendance(month);
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      final data = response['data'];
      final raw = data is Map ? data['records'] : null;
      records = raw is List
          ? raw.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      // Newest day first.
      records.sort((a, b) =>
          (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()));
      status = StatusRequest.success;
    } else if (responseStatus == StatusRequest.offline) {
      status = StatusRequest.offline;
    } else {
      status = StatusRequest.failure;
    }

    update();
  }

  // ---- Aggregates for the summary header ----

  int get presentDays =>
      records.where((r) => (r['check_in_time']) != null).length;

  int _sum(String key) => records.fold<int>(
      0, (acc, r) => acc + (int.tryParse('${r[key] ?? 0}') ?? 0));

  int get lateDays => records.where((r) {
        final late = int.tryParse('${r['late_minutes'] ?? 0}') ?? 0;
        return late > 0;
      }).length;

  int get totalLateMinutes => _sum('late_minutes');
  int get totalOvertimeMinutes => _sum('overtime_minutes');
}
