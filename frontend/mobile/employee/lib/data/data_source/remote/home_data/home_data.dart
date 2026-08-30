import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class HomeData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getAttendanceMonth(String month) async {
    return await _crud.getData(
      AppLinks.attendanceMonth(month),
    );
  }
}
