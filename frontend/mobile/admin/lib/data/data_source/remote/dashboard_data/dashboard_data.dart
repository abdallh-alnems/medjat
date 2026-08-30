import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class DashboardData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> overview() async {
    return await _crud.postData(AppLinks.dashboardOverview, {});
  }
}
