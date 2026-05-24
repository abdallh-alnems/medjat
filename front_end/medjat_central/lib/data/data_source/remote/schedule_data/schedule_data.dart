import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class ScheduleData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getWeek(String weekStart, {int? branchId}) async {
    return await _crud.getData(AppLinks.scheduleWeek, queryParameters: {
      'week_start': weekStart,
      if (branchId != null) 'branch_id': branchId,
    });
  }

  /// Assign one shift (or rest, when shiftId is null) to many employees over many dates.
  Future<Map<String, dynamic>> assign({
    required List<int> employeeIds,
    required List<String> dates,
    int? shiftId,
  }) async {
    return await _crud.postData(AppLinks.scheduleAssign, {
      'employee_ids': employeeIds,
      'dates': dates,
      'shift_id': shiftId,
    });
  }

  Future<Map<String, dynamic>> clearCell({
    required int employeeId,
    required String workDate,
  }) async {
    return await _crud.postData(AppLinks.scheduleClear, {
      'employee_id': employeeId,
      'work_date': workDate,
    });
  }

  Future<Map<String, dynamic>> copyWeek({
    required String fromWeekStart,
    required String toWeekStart,
    int? branchId,
  }) async {
    return await _crud.postData(AppLinks.scheduleCopyWeek, {
      'from_week_start': fromWeekStart,
      'to_week_start': toWeekStart,
      if (branchId != null) 'branch_id': branchId,
    });
  }

  Future<Map<String, dynamic>> publish(String weekStart, {int? branchId}) async {
    return await _crud.postData(AppLinks.schedulePublish, {
      'week_start': weekStart,
      if (branchId != null) 'branch_id': branchId,
    });
  }
}
