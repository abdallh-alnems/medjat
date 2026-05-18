import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class TenantData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> createCompany({
    required String firebaseToken,
    required String companyName,
    String? companyNameAr,
    String? phone,
  }) async {
    return await _crud.postData(AppLinks.tenantCreate, {
      'token': firebaseToken,
      'company_name': companyName,
      if (companyNameAr != null && companyNameAr.isNotEmpty)
        'company_name_ar': companyNameAr,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
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
