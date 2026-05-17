import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/app_links.dart';

class AttendanceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getAttendance({
    String? date,
    int? branchId,
    int? employeeId,
  }) async {
    final params = <String, dynamic>{};
    if (date != null) params['date'] = date;
    if (branchId != null) params['branch_id'] = branchId;
    if (employeeId != null) params['employee_id'] = employeeId;
    return await _crud.getData(AppLinks.attendance, queryParameters: params);
  }

  Future<Map<String, dynamic>> manualCheckIn(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.attendanceManual, data);
  }
}
