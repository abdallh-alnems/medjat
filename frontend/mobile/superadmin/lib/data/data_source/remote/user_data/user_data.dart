import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

/// The client contact book, plus what we can do on a client's behalf when they
/// call: suspend an account, restore it, send its owner a password-reset link,
/// or open their dashboard for a diagnostic look.
class UserData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> list({
    int page = 1,
    int limit = 20,
    int? tenantId,
    String? q,
    String? role,
    String? status,
  }) async {
    final data = <String, dynamic>{'page': page, 'limit': limit};
    if (tenantId != null) data['tenant_id'] = tenantId;
    if (q != null && q.isNotEmpty) data['q'] = q;
    if (role != null && role.isNotEmpty) data['role'] = role;
    if (status != null && status.isNotEmpty) data['status'] = status;
    return await _crud.getData(AppLinks.users, queryParameters: data);
  }

  Future<Map<String, dynamic>> setActive(int adminId, bool isActive) async {
    return await _crud.postData(AppLinks.companyAdminSetActive, {
      'admin_id': adminId,
      'is_active': isActive ? 1 : 0,
    });
  }

  Future<Map<String, dynamic>> sendPasswordReset(int adminId) async {
    return await _crud.postData(AppLinks.companyAdminResetPassword, {'admin_id': adminId});
  }

  /// Mints a one-hour diagnostic session for this administrator. The reason is
  /// mandatory and lands in the company's own audit log.
  Future<Map<String, dynamic>> impersonate(int adminId, String reason) async {
    return await _crud.postData(AppLinks.companyAdminImpersonate, {
      'admin_id': adminId,
      'reason': reason,
    });
  }
}
