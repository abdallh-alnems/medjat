import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/app_links.dart';

class DashboardData {
  final CRUD _crud = Get.find<CRUD>();

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
