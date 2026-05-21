import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class CategoryData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getCategories() async {
    return await _crud.getData(AppLinks.categories);
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.categoryCreate, data);
  }

  Future<Map<String, dynamic>> updateCategory(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.categoryUpdate, data);
  }

  Future<Map<String, dynamic>> deleteCategory(int id) async {
    return await _crud.postData(AppLinks.categoryDelete, {'id': id});
  }

  Future<Map<String, dynamic>> assignCategories({
    required int employeeId,
    required List<int> categoryIds,
  }) async {
    return await _crud.postData(AppLinks.categoryAssign, {
      'employee_id': employeeId,
      'category_ids': categoryIds,
    });
  }
}
