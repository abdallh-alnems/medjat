import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/attendance_model.dart';
import '../../../data/model/employee_model.dart';

class AttendanceController extends GetxController {
  final AttendanceData _attendanceData = Get.find<AttendanceData>();
  final EmployeeData _employeeData = Get.find<EmployeeData>();

  StatusRequest status = StatusRequest.none;
  List<AttendanceRecordModel> records = [];
  DateTime selectedDate = DateTime.now();
  int? branchFilter;
  bool hasEmployees = true;

  @override
  void onInit() {
    super.onInit();
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
    loadAttendance();
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
    );

    if (response['status'] == StatusRequest.success) {
      records = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
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

  void changeDate(DateTime date) {
    selectedDate = date;
    loadAttendance();
  }

  void filterByBranch(int? branchId) {
    branchFilter = branchId;
    loadAttendance();
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
