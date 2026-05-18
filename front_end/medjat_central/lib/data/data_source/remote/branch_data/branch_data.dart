import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class BranchData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getBranches() async {
    return await _crud.getData(AppLinks.branches);
  }

  Future<Map<String, dynamic>> getBranch(int id) async {
    return await _crud.getData(AppLinks.branchDetail(id));
  }

  Future<Map<String, dynamic>> createBranch(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.branches, data);
  }

  Future<Map<String, dynamic>> updateBranch(int id, Map<String, dynamic> data) async {
    return await _crud.putData(AppLinks.branchDetail(id), data);
  }
}
