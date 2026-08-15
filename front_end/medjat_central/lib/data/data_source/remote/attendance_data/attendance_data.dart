import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class AttendanceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getAttendance({
    String? date,
    int? branchId,
    int? shiftId,
    int? categoryId,
    int? employeeId,
  }) async {
    final params = <String, dynamic>{};
    if (date != null) params['date'] = date;
    if (branchId != null) params['branch_id'] = branchId;
    if (shiftId != null) params['shift_id'] = shiftId;
    if (categoryId != null) params['category_id'] = categoryId;
    if (employeeId != null) params['employee_id'] = employeeId;
    return await _crud.getData(AppLinks.attendance, queryParameters: params);
  }

  Future<Map<String, dynamic>> manualCheckIn(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.attendanceManual, data);
  }

  Future<Map<String, dynamic>> updateNote({
    int? attendanceId,
    int? employeeId,
    String? date,
    String? note,
  }) async {
    final body = <String, dynamic>{'note': note ?? ''};
    if (attendanceId != null && attendanceId > 0) {
      body['attendance_id'] = attendanceId;
    } else {
      if (employeeId != null) body['employee_id'] = employeeId;
      if (date != null) body['date'] = date;
    }
    return await _crud.postData(AppLinks.attendanceUpdateNote, body);
  }

  /// Unified day-status editor. Sets one calendar day to
  /// `present` / `absent` / `leave`, creating the record if needed.
  Future<Map<String, dynamic>> setDayStatus({
    required int employeeId,
    required String date,
    required String status,
    String? checkInTime,
    String? checkOutTime,
    String? leaveType,
    String? reason,
    String? deductionMode,
    num? deductionValue,
  }) async {
    final body = <String, dynamic>{
      'employee_id': employeeId,
      'date': date,
      'status': status,
    };
    if (checkInTime != null) body['check_in_time'] = checkInTime;
    if (checkOutTime != null) body['check_out_time'] = checkOutTime;
    if (leaveType != null) body['leave_type'] = leaveType;
    if (reason != null) body['reason'] = reason;
    if (deductionMode != null) body['deduction_mode'] = deductionMode;
    if (deductionValue != null) body['deduction_value'] = deductionValue;
    return await _crud.postData(AppLinks.attendanceSetDayStatus, body);
  }

  /// The image captured at a browser punch, as raw bytes.
  ///
  /// Fetched on demand rather than with the day's list: a branch review would
  /// otherwise download a photograph of every employee before anyone asked to
  /// see one.
  Future<Map<String, dynamic>> getPunchPhoto({
    required int attendanceId,
    required String which,
  }) async {
    return await _crud
        .getBytes(AppLinks.attendancePunchPhoto(attendanceId, which));
  }
}
