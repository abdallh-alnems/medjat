import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class RoleData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getRoles() async {
    return await _crud.getData(AppLinks.roles);
  }

  Future<Map<String, dynamic>> createRole(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.roles, data);
  }

  Future<Map<String, dynamic>> updateRole(
      int id, Map<String, dynamic> data) async {
    return await _crud.putData('${AppLinks.roles}/$id', data);
  }

  Future<Map<String, dynamic>> deleteRole(int id) async {
    return await _crud.deleteData('${AppLinks.roles}/$id');
  }
}
