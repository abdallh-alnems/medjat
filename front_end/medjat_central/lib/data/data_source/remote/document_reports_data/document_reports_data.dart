import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class DocumentReportsData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getExpiringSoon({int daysAhead = 30, int? branchId}) async {
    final params = <String, dynamic>{'days_ahead': daysAhead};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.documentReportsExpiringSoon, queryParameters: params);
  }

  Future<Map<String, dynamic>> getExpired({int? branchId}) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.documentReportsExpired, queryParameters: params);
  }

  Future<Map<String, dynamic>> getMissing({int? branchId, int? employeeId}) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    if (employeeId != null) params['employee_id'] = employeeId;
    return await _crud.getData(AppLinks.documentReportsMissing, queryParameters: params);
  }

  Future<Map<String, dynamic>> getStats() async {
    return await _crud.getData(AppLinks.documentReportsStats);
  }

  Future<Map<String, dynamic>> markExpired() async {
    return await _crud.postData(AppLinks.documentMarkExpired, {});
  }
}
