import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

/// Remote calls for the terminated-employees ("re-hire") screen.
class TerminatedEmployeeData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> listTerminated({
    String? search,
    int? page,
    int? limit,
  }) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (page != null) params['page'] = page;
    if (limit != null) params['limit'] = limit;
    return await _crud.getData(AppLinks.employeesTerminated,
        queryParameters: params);
  }

  Future<Map<String, dynamic>> reactivate(int employeeId) async {
    return await _crud
        .postData(AppLinks.employeeReactivate, {'employee_id': employeeId});
  }
}
