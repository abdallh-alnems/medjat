import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class AuditData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> list({int page = 1}) async {
    return await _crud.postData(AppLinks.auditLog, {'page': page});
  }
}
