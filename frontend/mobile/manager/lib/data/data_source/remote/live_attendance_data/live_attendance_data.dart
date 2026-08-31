import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class LiveAttendanceData {
  final CRUD _crud = Get.find<CRUD>();

  // If not yet supported, the default behaviour returns all employees.
  Future<Map<String, dynamic>> getLiveBoard(
      {int? branchId, int? shiftId, int? categoryId}) {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    if (shiftId != null) params['shift_id'] = shiftId;
    if (categoryId != null) params['category_id'] = categoryId;
    return _crud.getData(
      AppLinks.liveAttendance,
      queryParameters: params.isNotEmpty ? params : null,
    );
  }
}
