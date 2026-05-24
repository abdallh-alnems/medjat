import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class DashboardData {
  final CRUD _crud = Get.find<CRUD>();

  // TODO: Ensure /dashboard endpoint returns branch_stats with:
  //   total_payroll (double), late (int), late_rate (double)
  //   If backend doesn't return them yet, default 0 will be used in the model.
  Future<Map<String, dynamic>> getDashboard() async {
    return await _crud.getData(AppLinks.dashboard);
  }

  Future<Map<String, dynamic>> getDashboardByBranch(int branchId) async {
    return await _crud.getData(
      AppLinks.dashboard,
      queryParameters: {'branch_id': branchId},
    );
  }

  // TODO: Backend must support category_id param on overview.php.
  // If not yet supported, the default behaviour returns all employees.
  Future<Map<String, dynamic>> getDashboardFiltered({
    int? branchId,
    int? shiftId,
    int? categoryId,
  }) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    if (shiftId != null) params['shift_id'] = shiftId;
    if (categoryId != null) params['category_id'] = categoryId;
    return await _crud.getData(
      AppLinks.dashboard,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }
}
