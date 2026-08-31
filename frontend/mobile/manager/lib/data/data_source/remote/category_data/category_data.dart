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

  /// The model still builds its update payload with `id` inside it, and the
  /// id now belongs in the path, so it is lifted out here rather than sent
  /// twice.
  Future<Map<String, dynamic>> updateCategory(Map<String, dynamic> data) async {
    final body = Map<String, dynamic>.from(data)..remove('id');
    return await _crud.patchData(
        AppLinks.categoryUpdate(data['id'] as int), body);
  }

  Future<Map<String, dynamic>> deleteCategory(int id) async {
    return await _crud.deleteData(AppLinks.categoryDelete(id));
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
