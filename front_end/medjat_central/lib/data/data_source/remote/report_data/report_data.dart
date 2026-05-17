import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/app_links.dart';

class ReportData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getAttendanceReport({
    String? startDate,
    String? endDate,
    int? branchId,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.reportAttendance, queryParameters: params);
  }

  Future<Map<String, dynamic>> getPayrollReport({
    int? month,
    int? year,
    int? branchId,
  }) async {
    final params = <String, dynamic>{};
    if (month != null) params['month'] = month;
    if (year != null) params['year'] = year;
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.reportPayroll, queryParameters: params);
  }
}
