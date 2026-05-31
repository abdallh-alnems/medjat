import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class ShiftData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getShifts({int? branchId}) async {
    return await _crud.getData(AppLinks.shifts,
        queryParameters: branchId != null ? {'branch_id': branchId} : null);
  }

  Future<Map<String, dynamic>> createShift(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.shiftCreate, data);
  }

  Future<Map<String, dynamic>> updateShift(int id, Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.shiftUpdate(id), data);
  }

  Future<Map<String, dynamic>> deleteShift(int id) async {
    return await _crud.postData(AppLinks.shiftDelete(id), {});
  }

  Future<Map<String, dynamic>> assignEmployees({
    required int shiftId,
    required List<int> employeeIds,
  }) async {
    return await _crud.postData(AppLinks.shiftAssign, {
      'shift_id': shiftId,
      'employee_ids': employeeIds,
    });
  }

  Future<Map<String, dynamic>> unassignEmployees({
    required int shiftId,
    required List<int> employeeIds,
  }) async {
    return await _crud.postData(AppLinks.shiftUnassign, {
      'shift_id': shiftId,
      'employee_ids': employeeIds,
    });
  }
}
