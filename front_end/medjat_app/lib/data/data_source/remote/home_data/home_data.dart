import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/app_links.dart';

class HomeData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getTodayStatus() async {
    final response = await _crud.getData(AppLinks.today);
    if (response['status'] == StatusRequest.success) {
      return response;
    }
    return response;
  }
}
