import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/attendance_model.dart';
import '../../../data/model/employee_model.dart';
import '../../../logic/controller/branch/branch_controller.dart';
import '../../../logic/controller/shift/shift_controller.dart';
import '../../../logic/controller/category/category_controller.dart';

class AttendanceController extends GetxController {
  final AttendanceData _attendanceData = Get.find<AttendanceData>();
  final EmployeeData _employeeData = Get.find<EmployeeData>();

  StatusRequest status = StatusRequest.none;
  List<AttendanceRecordModel> records = [];
  DateTime selectedDate = DateTime.now();
  int? branchFilter;
  int? shiftFilter;
  int? categoryFilter;
  String? statusFilter;
  String searchQuery = '';
  String sortBy = 'name'; // 'name' | 'status' | 'check_in'
  bool hasEmployees = true;

  /// IDs of employees we've already seen as late — used to detect *new* late
  /// arrivals between refreshes for the in-app banner.
  final Set<int> _knownLateEmployeeIds = <int>{};
  int newLatecomersCount = 0;
  bool _firstLoadDone = false;
  bool latecomerBannerDismissed = false;

  int get activeFilterCount {
    int c = 0;
    if (branchFilter != null) c++;
    if (shiftFilter != null) c++;
    if (categoryFilter != null) c++;
    return c;
  }

  int get presentCount => records.where((r) => r.status == 'present').length;
  int get absentCount => records.where((r) => r.status == 'absent').length;
  int get lateCount =>
      records.where((r) => (r.lateMinutes ?? 0) > 0).length;
  int get leaveCount => records
      .where((r) =>
          r.status == 'leave' ||
          r.status == 'holiday' ||
          r.status == 'weekly_off')
      .length;
  int get halfDayCount => records.where((r) => r.status == 'half_day').length;
  int get notArrivedCount =>
      records.where((r) => r.status == 'not_arrived').length;

  int get attendedCount =>
      records.where((r) => r.status == 'present').length;

  int get attendanceRatePercent {
    if (records.isEmpty) return 0;
    return ((attendedCount / records.length) * 100).round();
  }

  int get averageLateMinutes {
    final lateRecords =
        records.where((r) => (r.lateMinutes ?? 0) > 0).toList();
    if (lateRecords.isEmpty) return 0;
    final sum = lateRecords.fold<double>(
        0, (acc, r) => acc + (r.lateMinutes ?? 0));
    return (sum / lateRecords.length).round();
  }

  List<AttendanceRecordModel> get filteredRecords {
    var list = records.toList();
    if (statusFilter != null) {
      list = list.where((r) {
        if (statusFilter == 'late') return (r.lateMinutes ?? 0) > 0;
        if (statusFilter == 'leave') {
          return r.status == 'leave' ||
              r.status == 'holiday' ||
              r.status == 'weekly_off';
        }
        return r.status == statusFilter;
      }).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list
          .where((r) =>
              (r.employeeName ?? '').toLowerCase().contains(q))
          .toList();
    }
    list.sort(_compareForSort);
    return list;
  }

  int _compareForSort(AttendanceRecordModel a, AttendanceRecordModel b) {
    switch (sortBy) {
      case 'status':
        const order = {
          'present': 0,
          'late': 1,
          'leave': 2,
          'absent': 3,
          'holiday': 4,
          'weekly_off': 5,
        };
        final aKey = (a.lateMinutes ?? 0) > 0 ? 'late' : a.status;
        final bKey = (b.lateMinutes ?? 0) > 0 ? 'late' : b.status;
        final cmp = (order[aKey] ?? 99).compareTo(order[bKey] ?? 99);
        if (cmp != 0) return cmp;
        return (a.employeeName ?? '').compareTo(b.employeeName ?? '');
      case 'check_in':
        final ax = a.checkIn;
        final bx = b.checkIn;
        if (ax == null && bx == null) {
          return (a.employeeName ?? '').compareTo(b.employeeName ?? '');
        }
        if (ax == null) return 1; // nulls go last
        if (bx == null) return -1;
        return ax.compareTo(bx);
      case 'name':
      default:
        return (a.employeeName ?? '').compareTo(b.employeeName ?? '');
    }
  }

  void setSortBy(String key) {
    if (sortBy == key) return;
    sortBy = key;
    update();
  }

  @override
  void onInit() {
    super.onInit();
    Get.find<BranchController>();
    Get.find<ShiftController>();
    Get.find<CategoryController>();
    _checkEmployees();
  }

  Future<void> _checkEmployees() async {
    try {
      final response = await _employeeData.getEmployees();
      if (response['status'] == StatusRequest.success) {
        hasEmployees = _extractRawList(response['data']).isNotEmpty;
      }
    } catch (_) {}
    if (!hasEmployees) {
      status = StatusRequest.success;
      records = [];
      update();
      return;
    }
    await loadAttendance();
  }

  List<dynamic> _extractRawList(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) {
      payload = payload['data'];
    }
    if (payload is List) return payload;
    if (payload is Map) {
      for (final key in const ['items', 'records', 'list', 'data']) {
        if (payload[key] is List) return payload[key] as List;
      }
    }
    return const [];
  }

  Future<void> loadAttendance() async {
    status = StatusRequest.loading;
    update();

    final dateStr =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    final response = await _attendanceData.getAttendance(
      date: dateStr,
      branchId: branchFilter,
      shiftId: shiftFilter,
      categoryId: categoryFilter,
    );

    if (response['status'] == StatusRequest.success) {
      records = _extractItems(response['data']);
      _detectNewLatecomers();
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void _detectNewLatecomers() {
    final currentLateIds = records
        .where((r) => (r.lateMinutes ?? 0) > 0)
        .map((r) => r.employeeId)
        .toSet();

    if (!_firstLoadDone) {
      // Seed the baseline on the first load — don't surface a banner for
      // records that were already late before the user opened the screen.
      _knownLateEmployeeIds
        ..clear()
        ..addAll(currentLateIds);
      _firstLoadDone = true;
      newLatecomersCount = 0;
      return;
    }

    final newIds = currentLateIds.difference(_knownLateEmployeeIds);
    if (newIds.isNotEmpty) {
      newLatecomersCount = newIds.length;
      latecomerBannerDismissed = false;
      _knownLateEmployeeIds.addAll(newIds);
    }
  }

  void dismissLatecomerBanner() {
    latecomerBannerDismissed = true;
    newLatecomersCount = 0;
    update();
  }

  List<AttendanceRecordModel> _extractItems(dynamic raw) {
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
        .map(AttendanceRecordModel.fromJson)
        .toList();
  }

  void _resetLatecomerBaseline() {
    _firstLoadDone = false;
    _knownLateEmployeeIds.clear();
    newLatecomersCount = 0;
    latecomerBannerDismissed = false;
  }

  void changeDate(DateTime date) {
    selectedDate = date;
    _resetLatecomerBaseline();
    loadAttendance();
  }

  void filterByBranch(int? branchId) {
    branchFilter = branchId;
    _resetLatecomerBaseline();
    loadAttendance();
  }

  void applyFilters({int? branchId, int? shiftId, int? categoryId}) {
    branchFilter = branchId;
    shiftFilter = shiftId;
    categoryFilter = categoryId;
    _resetLatecomerBaseline();
    loadAttendance();
  }

  void clearFilters() {
    branchFilter = null;
    shiftFilter = null;
    categoryFilter = null;
    statusFilter = null;
    searchQuery = '';
    _resetLatecomerBaseline();
    loadAttendance();
  }

  void toggleStatusFilter(String? status) {
    statusFilter = statusFilter == status ? null : status;
    update();
  }

  void onSearch(String query) {
    searchQuery = query;
    update();
  }

  Future<bool> recordManualAttendance({
    required int employeeId,
    required int branchId,
    required DateTime date,
    TimeOfDay? checkInTime,
    TimeOfDay? checkOutTime,
  }) async {
    if (checkInTime == null && checkOutTime == null) {
      Get.snackbar('error'.tr, 'select_check_in_or_check_out'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String fmtTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

    final payload = <String, dynamic>{
      'employee_id': employeeId,
      'branch_id': branchId,
      'date': fmtDate(date),
    };
    if (checkInTime != null) payload['check_in_time'] = fmtTime(checkInTime);
    if (checkOutTime != null) payload['check_out_time'] = fmtTime(checkOutTime);

    final response = await _attendanceData.manualCheckIn(payload);

    if (response['status'] == StatusRequest.success) {
      final isCheckOutOnly = checkInTime == null && checkOutTime != null;
      Get.snackbar(
        'done'.tr,
        isCheckOutOnly
            ? 'check_out_recorded'.tr
            : 'check_in_recorded'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      await loadAttendance();
      return true;
    }
    final msg = (response['message'] as String?) ?? 'manual_attendance_failed'.tr;
    Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  Future<int> recordManualAttendanceBatch({
    required List<EmployeeModel> employees,
    required DateTime date,
    TimeOfDay? checkInTime,
    TimeOfDay? checkOutTime,
    String? notes,
  }) async {
    if (employees.isEmpty) return 0;
    if (checkInTime == null && checkOutTime == null) {
      Get.snackbar('error'.tr, 'select_check_in_or_check_out'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return 0;
    }

    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    String fmtTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

    final cleanNote = notes?.trim();
    var successCount = 0;
    final failures = <String>[];

    for (final emp in employees) {
      final payload = <String, dynamic>{
        'employee_id': emp.id,
        'branch_id': emp.branchId,
        'date': fmtDate(date),
      };
      if (checkInTime != null) payload['check_in_time'] = fmtTime(checkInTime);
      if (checkOutTime != null) payload['check_out_time'] = fmtTime(checkOutTime);
      if (cleanNote != null && cleanNote.isNotEmpty) {
        payload['notes'] = cleanNote;
      }

      final response = await _attendanceData.manualCheckIn(payload);
      if (response['status'] == StatusRequest.success) {
        successCount++;
      } else {
        failures.add(emp.name);
      }
    }

    await loadAttendance();

    if (successCount > 0) {
      Get.snackbar(
        'done'.tr,
        '${'manual_attendance_recorded_for'.tr} $successCount',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
    if (failures.isNotEmpty) {
      Get.snackbar(
        'error'.tr,
        '${'manual_attendance_failed_for'.tr}: ${failures.join('، ')}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
    return successCount;
  }

  Future<bool> updateAttendanceNote({
    required AttendanceRecordModel record,
    required String? note,
  }) async {
    final clean = note?.trim();
    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final response = await _attendanceData.updateNote(
      attendanceId: record.id > 0 ? record.id : null,
      employeeId: record.id > 0 ? null : record.employeeId,
      date: record.id > 0 ? null : fmtDate(selectedDate),
      note: clean,
    );

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'note_saved'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadAttendance();
      return true;
    }
    final msg = (response['message'] as String?) ?? 'note_save_failed'.tr;
    Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  List<EmployeeModel> getEmployeesWithoutRecord(List<EmployeeModel> allEmployees) {
    final recordedIds = records.map((r) => r.employeeId).toSet();
    return allEmployees.where((e) => !recordedIds.contains(e.id)).toList();
  }

  List<EmployeeModel> getEmployeesEligibleForCheckIn(List<EmployeeModel> allEmployees) {
    final withCheckIn = records
        .where((r) => r.checkIn != null)
        .map((r) => r.employeeId)
        .toSet();
    return allEmployees.where((e) => !withCheckIn.contains(e.id)).toList();
  }

  List<EmployeeModel> getEmployeesEligibleForCheckOut(List<EmployeeModel> allEmployees) {
    final pendingCheckOut = records
        .where((r) => r.checkIn != null && r.checkOut == null)
        .map((r) => r.employeeId)
        .toSet();
    return allEmployees.where((e) => pendingCheckOut.contains(e.id)).toList();
  }
}
