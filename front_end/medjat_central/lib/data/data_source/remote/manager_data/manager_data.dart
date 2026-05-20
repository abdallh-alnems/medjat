import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class ManagerData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> createInvitation(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.managerInvite, data);
  }

  Future<Map<String, dynamic>> getInvitations({String? status}) async {
    return await _crud.getData(
      AppLinks.managerInvitations,
      queryParameters: status != null ? {'status': status} : null,
    );
  }

  Future<Map<String, dynamic>> cancelInvitation(int id) async {
    return await _crud.postData(AppLinks.managerCancelInvitation(id), {});
  }

  Future<Map<String, dynamic>> getAdmins() async {
    return await _crud.getData(AppLinks.adminsList);
  }

  Future<Map<String, dynamic>> getAdminPermissions(int adminId) async {
    return await _crud.getData(AppLinks.adminPermissions(adminId));
  }

  Future<Map<String, dynamic>> updateAdminPermissions({
    required int adminId,
    required List<String> permissions,
  }) async {
    return await _crud.postData(
      AppLinks.adminPermissionsUpdate,
      {'admin_id': adminId, 'permissions': permissions},
    );
  }

  Future<Map<String, dynamic>> resetAdminPermissions(int adminId) async {
    return await _crud.postData(
      AppLinks.adminPermissionsReset,
      {'admin_id': adminId},
    );
  }
}
