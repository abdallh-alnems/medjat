import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class TenantData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> createCompany({
    required String firebaseToken,
    required String companyName,
  }) async {
    return await _crud.postData(AppLinks.tenantCreate, {
      'token': firebaseToken,
      'company_name': companyName,
    });
  }

  Future<Map<String, dynamic>> joinCompany({
    required String firebaseToken,
    required String inviteCode,
  }) async {
    return await _crud.postData(AppLinks.tenantJoin, {
      'token': firebaseToken,
      'invite_code': inviteCode,
    });
  }
}
