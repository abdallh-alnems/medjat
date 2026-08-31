import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class TenantData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> list({
    int page = 1,
    int limit = 20,
    String? q,
    String? status,
  }) async {
    final data = <String, dynamic>{'page': page, 'limit': limit};
    if (q != null && q.isNotEmpty) data['q'] = q;
    if (status != null && status.isNotEmpty) data['status'] = status;
    return await _crud.postData(AppLinks.tenants, data);
  }

  Future<Map<String, dynamic>> detail(int id) async {
    return await _crud.getData(AppLinks.tenantDetail, queryParameters: {'id': id});
  }

  Future<Map<String, dynamic>> diagnostics(int id, {int days = 30}) async {
    return await _crud.getData(AppLinks.tenantDiagnostics,
        queryParameters: {'id': id, 'days': days});
  }

  /// Onboards a company: the tenant row plus, when an owner email is given, a
  /// pending general_manager invitation emailed to them.
  Future<Map<String, dynamic>> create({
    required String name,
    String? timezone,
    String? currency,
    String? contactName,
    String? contactEmail,
    String? contactPhone,
    String? opsNotes,
    String? ownerEmail,
    String? ownerName,
  }) async {
    final data = <String, dynamic>{'name': name};
    void put(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) data[key] = value.trim();
    }

    put('timezone', timezone);
    put('currency', currency);
    put('contact_name', contactName);
    put('contact_email', contactEmail);
    put('contact_phone', contactPhone);
    put('ops_notes', opsNotes);
    put('owner_email', ownerEmail);
    put('owner_name', ownerName);

    return await _crud.postData(AppLinks.tenantCreate, data);
  }

  /// Only the keys present are written, so editing a phone number cannot reset
  /// a timezone the caller never saw.
  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> fields) async {
    return await _crud.patchData(AppLinks.tenantUpdate(id), fields);
  }

  Future<Map<String, dynamic>> activate(int id) async {
    return await _crud.postData(AppLinks.tenantActivate, {'id': id});
  }

  Future<Map<String, dynamic>> deactivate(int id) async {
    return await _crud.postData(AppLinks.tenantDeactivate, {'id': id});
  }

  Future<Map<String, dynamic>> inviteManager({
    required int tenantId,
    required String email,
    String? name,
    String role = 'general_manager',
  }) async {
    return await _crud.postData(AppLinks.companyAdminInvite, {
      'tenant_id': tenantId,
      'email': email,
      if (name != null && name.isNotEmpty) 'name': name,
      'role': role,
    });
  }
}
