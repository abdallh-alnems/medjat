import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/model/employee_category_model.dart';

class CategoryController extends GetxController {
  final CategoryData _data = Get.find<CategoryData>();

  StatusRequest status = StatusRequest.none;
  List<EmployeeCategoryModel> categories = [];

  @override
  void onInit() {
    super.onInit();
    loadCategories();
  }

  Future<void> loadCategories() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getCategories();

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) {
        body = body['data'];
      }
      if (body is Map && body['categories'] is List) {
        categories = (body['categories'] as List)
            .map((e) =>
                EmployeeCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (body is List) {
        categories = body
            .map((e) =>
                EmployeeCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  Future<void> createCategory(EmployeeCategoryModel cat) async {
    final response = await _data.createCategory(cat.toCreateJson());
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'category_created'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadCategories();
    } else {
      final msg = (response['message'] as String?) ?? 'error'.tr;
      Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> updateCategory(EmployeeCategoryModel cat) async {
    final response = await _data.updateCategory(cat.toUpdateJson());
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'category_updated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadCategories();
    } else {
      final msg = (response['message'] as String?) ?? 'error'.tr;
      Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<bool> deleteCategory(int id) async {
    final response = await _data.deleteCategory(id);
    if (response['status'] == StatusRequest.success) {
      categories.removeWhere((c) => c.id == id);
      Get.snackbar('done'.tr, 'category_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      update();
      return true;
    } else {
      final msg = (response['message'] as String?) ?? 'error'.tr;
      Get.snackbar('error'.tr, msg, snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }
}
