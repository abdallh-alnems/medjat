import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class LiveAttendanceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getLiveBoard({int? branchId}) {
    return _crud.getData(
      AppLinks.liveAttendance,
      queryParameters: branchId != null ? {'branch_id': branchId} : null,
    );
  }
}
