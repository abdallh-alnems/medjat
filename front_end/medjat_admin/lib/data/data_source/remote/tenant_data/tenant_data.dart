import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';
import '../../../model/tenant_model.dart';

class TenantData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> list({int page = 1}) async {
    return await _crud.postData(AppLinks.tenants, {'page': page});
  }

  Future<Map<String, dynamic>> detail(int id) async {
    return await _crud.postData(AppLinks.tenantDetail, {'id': id});
  }

  Future<Map<String, dynamic>> create(TenantModel tenant) async {
    return await _crud.postData(AppLinks.tenantCreate, {
      'name': tenant.name,
      'name_ar': tenant.nameAr,
      'owner_name': tenant.ownerName,
      'owner_email': tenant.ownerEmail,
      'owner_phone': tenant.ownerPhone,
    });
  }

  Future<Map<String, dynamic>> activate(int id) async {
    return await _crud.postData(AppLinks.tenantActivate, {'id': id});
  }

  Future<Map<String, dynamic>> deactivate(int id) async {
    return await _crud.postData(AppLinks.tenantDeactivate, {'id': id});
  }
}
