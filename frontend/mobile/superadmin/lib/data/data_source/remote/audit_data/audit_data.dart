import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class AuditData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> list({
    int page = 1,
    int limit = 50,
    String? action,
    String? q,
    String? from,
    String? to,
  }) async {
    final data = <String, dynamic>{'page': page, 'limit': limit};
    if (action != null && action.isNotEmpty) data['action'] = action;
    if (q != null && q.isNotEmpty) data['q'] = q;
    if (from != null && from.isNotEmpty) data['from'] = from;
    if (to != null && to.isNotEmpty) data['to'] = to;
    return await _crud.getData(AppLinks.auditLog, queryParameters: data);
  }
}
