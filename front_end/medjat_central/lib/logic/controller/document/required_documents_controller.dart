import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/required_documents_data/required_documents_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/model/required_document_model.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/employee_model.dart';
import '../../../data/model/employee_category_model.dart';

class RequiredDocumentsController extends GetxController {
  final RequiredDocumentsData _data = Get.find<RequiredDocumentsData>();
  final BranchData _branchData = Get.find<BranchData>();
  final EmployeeData _employeeData = Get.find<EmployeeData>();
  final CategoryData _categoryData = Get.find<CategoryData>();

  StatusRequest status = StatusRequest.none;
  List<RequiredDocumentModel> documents = [];
  List<BranchModel> branches = [];
  List<EmployeeModel> employees = [];
  List<EmployeeCategoryModel> categories = [];

  @override
  void onInit() {
    super.onInit();
    loadDocuments();
    loadBranches();
    loadEmployees();
    loadCategories();
  }

  Future<void> loadBranches() async {
    final response = await _branchData.getBranches();
    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) body = body['data'];
      if (body is Map && body['branches'] is List) {
        branches = (body['branches'] as List)
            .map((e) => BranchModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (body is List) {
        branches = body
            .map((e) => BranchModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      update();
    }
  }

  Future<void> loadEmployees() async {
    final response = await _employeeData.getEmployees();
    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) body = body['data'];
      // The employees list endpoint returns the array under `items`; older
      // shapes used `employees`. Support both.
      if (body is Map && body['items'] is List) {
        employees = (body['items'] as List)
            .map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (body is Map && body['employees'] is List) {
        employees = (body['employees'] as List)
            .map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (body is List) {
        employees = body
            .map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      update();
    }
  }

  Future<void> loadCategories() async {
    final response = await _categoryData.getCategories();
    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) body = body['data'];
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
      update();
    }
  }

  Future<void> loadDocuments() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getRequired();

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) {
        body = body['data'];
      }
      if (body is Map && body['required_documents'] is List) {
        documents = (body['required_documents'] as List)
            .map((e) => RequiredDocumentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (body is List) {
        documents = body
            .map((e) => RequiredDocumentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  Future<void> createDocument(RequiredDocumentModel doc) async {
    final response = await _data.createRequired(doc.toCreateJson());
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_type_created'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadDocuments();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> updateDocument(RequiredDocumentModel doc) async {
    final response = await _data.updateRequired(doc.toUpdateJson());
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_type_updated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadDocuments();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> deleteDocument(int id) async {
    final response = await _data.deleteRequired(id);
    if (response['status'] == StatusRequest.success) {
      documents.removeWhere((d) => d.id == id);
      Get.snackbar('done'.tr, 'document_type_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      update();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> toggleActive(int id) async {
    final response = await _data.toggleRequired(id);
    if (response['status'] == StatusRequest.success) {
      await loadDocuments();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
