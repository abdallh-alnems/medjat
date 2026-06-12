import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class AuditData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getActivity({
    int page = 1,
    int? adminId,
    String? category,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (adminId != null) params['admin_id'] = adminId;
    if (category != null) params['category'] = category;
    return await _crud.getData(AppLinks.auditLog, queryParameters: params);
  }
}
