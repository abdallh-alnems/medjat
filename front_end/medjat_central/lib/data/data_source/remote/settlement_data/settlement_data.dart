import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class SettlementData {
  final CRUD _crud = Get.find<CRUD>();

  /// Saved settlement (if any) + a fresh suggestion to prefill a new one.
  Future<Map<String, dynamic>> get(int employeeId) async {
    return await _crud.getData(AppLinks.settlement(employeeId));
  }

  /// Recompute the suggested figures for a different last working day.
  Future<Map<String, dynamic>> preview(
      int employeeId, String lastWorkingDay) async {
    return await _crud.getData(
        AppLinks.settlementPreview(employeeId, lastWorkingDay));
  }

  Future<Map<String, dynamic>> save(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.settlementSave, data);
  }

  Future<Map<String, dynamic>> approve(int employeeId) async {
    return await _crud
        .postData(AppLinks.settlementApprove, {'employee_id': employeeId});
  }

  Future<Map<String, dynamic>> markPaid(int employeeId) async {
    return await _crud
        .postData(AppLinks.settlementMarkPaid, {'employee_id': employeeId});
  }
}
