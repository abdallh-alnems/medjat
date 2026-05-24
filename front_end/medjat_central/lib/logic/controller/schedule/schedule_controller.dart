import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/schedule_data/schedule_data.dart';
import '../../../data/model/schedule_model.dart';
import '../../../data/model/shift_model.dart';

class ScheduleController extends GetxController {
  final ScheduleData _data = Get.find<ScheduleData>();

  StatusRequest status = StatusRequest.none;
  bool busy = false; // a write (assign/copy/publish) is in flight

  /// Saturday of the week currently shown (start of the Arab work week).
  late DateTime weekStart;
  int? branchId;

  List<RosterEmployee> employees = [];
  List<ShiftModel> shifts = [];
  List<String> days = [];

  /// Cells keyed as "employeeId|YYYY-MM-DD" for O(1) grid lookup.
  final Map<String, ScheduleCell> _cells = {};

  @override
  void onInit() {
    super.onInit();
    weekStart = _saturdayOf(DateTime.now());
    loadWeek();
  }

  String get weekStartStr => _fmt(weekStart);
  String get weekEndStr => _fmt(weekStart.add(const Duration(days: 6)));
  bool get hasDraftCells => _cells.values.any((c) => c.isDraft);

  ScheduleCell? cellFor(int employeeId, String date) => _cells['$employeeId|$date'];

  Future<void> loadWeek() async {
    status = StatusRequest.loading;
    update();
    final response = await _data.getWeek(weekStartStr, branchId: branchId);
    if (response['status'] == StatusRequest.success) {
      final payload = _payload(response['data']);
      employees = _list(payload['employees']).map(RosterEmployee.fromJson).toList();
      shifts = _list(payload['shifts']).map(ShiftModel.fromJson).toList();
      days = (payload['days'] as List?)?.map((e) => e.toString()).toList() ?? _computeDays();
      _cells
        ..clear()
        ..addEntries(_list(payload['cells']).map((j) {
          final cell = ScheduleCell.fromJson(j);
          return MapEntry('${cell.employeeId}|${cell.workDate}', cell);
        }));
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  void goToWeek(DateTime newStart) {
    weekStart = _saturdayOf(newStart);
    loadWeek();
  }

  void nextWeek() => goToWeek(weekStart.add(const Duration(days: 7)));
  void previousWeek() => goToWeek(weekStart.subtract(const Duration(days: 7)));

  void setBranch(int? id) {
    branchId = id;
    loadWeek();
  }

  Future<bool> assign({
    required List<int> employeeIds,
    required List<String> dates,
    int? shiftId,
  }) async {
    return _run(() => _data.assign(employeeIds: employeeIds, dates: dates, shiftId: shiftId));
  }

  Future<bool> clearCell(int employeeId, String workDate) async {
    return _run(() => _data.clearCell(employeeId: employeeId, workDate: workDate));
  }

  Future<bool> copyPreviousWeek() async {
    final from = _fmt(weekStart.subtract(const Duration(days: 7)));
    return _run(() => _data.copyWeek(fromWeekStart: from, toWeekStart: weekStartStr, branchId: branchId));
  }

  Future<bool> publish() async {
    return _run(() => _data.publish(weekStartStr, branchId: branchId));
  }

  /// Runs a write call, reloads the week on success, and toggles [busy].
  Future<bool> _run(Future<Map<String, dynamic>> Function() call) async {
    busy = true;
    update();
    final response = await call();
    final ok = response['status'] == StatusRequest.success;
    busy = false;
    if (ok) {
      await loadWeek();
    } else {
      update();
    }
    return ok;
  }

  // ── helpers ──

  Map<String, dynamic> _payload(dynamic raw) {
    if (raw is Map && raw['data'] is Map) return Map<String, dynamic>.from(raw['data'] as Map);
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    return const [];
  }

  List<String> _computeDays() =>
      List.generate(7, (i) => _fmt(weekStart.add(Duration(days: i))));

  /// Saturday on or before [d] (Arab work week starts Saturday).
  DateTime _saturdayOf(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    // Dart weekday: Mon=1..Sun=7, Sat=6.
    final diff = (date.weekday - DateTime.saturday) % 7;
    return date.subtract(Duration(days: diff));
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
