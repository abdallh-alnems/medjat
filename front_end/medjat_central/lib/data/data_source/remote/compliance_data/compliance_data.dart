import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class ComplianceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getExpiring({int days = 30, int? branchId}) {
    final params = <String, dynamic>{'days': days};
    if (branchId != null) params['branch_id'] = branchId;
    return _crud.getData(AppLinks.expiringCompliance, queryParameters: params);
  }
}
