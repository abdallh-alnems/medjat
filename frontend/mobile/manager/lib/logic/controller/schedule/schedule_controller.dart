import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/company_settings_data/company_settings_data.dart';
import '../../../data/data_source/remote/schedule_data/schedule_data.dart';
import '../../../data/model/schedule_model.dart';
import '../../../data/model/shift_model.dart';

class ScheduleController extends GetxController {
  final ScheduleData _data = Get.find<ScheduleData>();
  final CompanySettingsData _settingsData = Get.find<CompanySettingsData>();

  StatusRequest status = StatusRequest.none;
  bool busy = false; // a write (assign/copy/publish) is in flight

  /// Company-configured start weekday of the roster week (ISO: 1=Mon..7=Sun).
  int weekStartDay = 6;

  /// Start day of the week currently shown. The exact weekday is configured
  /// per-company (`week_start_day`); the backend snaps requests to it and
  /// echoes back the aligned [weekStart].
  late DateTime weekStart;

  /// Start of the current real-world week (server-aligned). Earliest week the
  /// user may navigate to; past weeks are read-only history.
  DateTime? currentWeekStart;
  int? branchId;

  List<RosterEmployee> employees = [];
  List<ShiftModel> shifts = [];
  List<String> days = [];

  /// Cells keyed as "employeeId|YYYY-MM-DD" for O(1) grid lookup.
  final Map<String, ScheduleCell> _cells = {};

  @override
  void onInit() {
    super.onInit();
    weekStart = _dateOnly(DateTime.now());
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
      // Adopt the server-aligned week boundaries (the backend snaps to the
      // company's configured start weekday).
      final ws = payload['week_start'] as String?;
      if (ws != null) weekStart = DateTime.parse(ws);
      final cws = payload['current_week_start'] as String?;
      if (cws != null) currentWeekStart = DateTime.parse(cws);
      weekStartDay = (payload['week_start_day'] as num?)?.toInt() ?? weekStartDay;
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
    weekStart = _dateOnly(newStart);
    loadWeek();
  }

  /// Whether the user may navigate one week back. The current real-world week
  /// is the earliest allowed; past weeks are read-only history.
  bool get canGoPrevious {
    final cur = currentWeekStart;
    if (cur == null) return false;
    return weekStart.isAfter(cur);
  }

  void nextWeek() => goToWeek(weekStart.add(const Duration(days: 7)));
  void previousWeek() {
    if (!canGoPrevious) return;
    goToWeek(weekStart.subtract(const Duration(days: 7)));
  }

  void setBranch(int? id) {
    branchId = id;
    loadWeek();
  }

  /// Persists the company-wide roster start weekday ([weekday] ISO 1=Mon..7=Sun)
  /// then jumps to the freshly aligned current week.
  Future<bool> changeWeekStartDay(int weekday) async {
    if (weekday == weekStartDay) return true;
    busy = true;
    update();
    final response =
        await _settingsData.updateCompanySettings({'week_start_day': weekday});
    final ok = response['status'] == StatusRequest.success;
    busy = false;
    if (ok) {
      weekStartDay = weekday;
      weekStart = _dateOnly(DateTime.now());
      await loadWeek();
    } else {
      update();
    }
    return ok;
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

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
