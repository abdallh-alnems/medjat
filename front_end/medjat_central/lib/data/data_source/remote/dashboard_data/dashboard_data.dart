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
}
