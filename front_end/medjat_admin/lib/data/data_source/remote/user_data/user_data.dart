import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class UserData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> list({int page = 1, int? tenantId}) async {
    final data = <String, dynamic>{'page': page};
    if (tenantId != null) data['tenant_id'] = tenantId;
    return await _crud.postData(AppLinks.users, data);
  }
}
