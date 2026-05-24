import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/shift_data/shift_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/model/employee_model.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/shift_model.dart';
import '../../../data/model/employee_category_model.dart';

class EmployeeController extends GetxController {
  final EmployeeData _employeeData = Get.find<EmployeeData>();
  final BranchData _branchData = Get.find<BranchData>();
  final ShiftData _shiftData = Get.find<ShiftData>();
  final CategoryData _categoryData = Get.find<CategoryData>();

  StatusRequest status = StatusRequest.none;
  List<EmployeeModel> employees = [];
  String searchQuery = '';

  int? branchFilter;
  int? shiftFilter;
  int? categoryFilter;

  List<BranchModel> branches = [];
  List<ShiftModel> shifts = [];
  List<EmployeeCategoryModel> categories = [];

  @override
  void onInit() {
    super.onInit();
    loadEmployees();
    loadFilterOptions();
  }

  Future<void> loadEmployees() async {
    status = StatusRequest.loading;
    update();

    final response = await _employeeData.getEmployees(
      branchId: branchFilter,
      shiftId: shiftFilter,
      categoryId: categoryFilter,
      search: searchQuery.isNotEmpty ? searchQuery : null,
    );

    if (response['status'] == StatusRequest.success) {
      employees = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> loadFilterOptions() async {
    final branchRes = await _branchData.getBranches();
    if (branchRes['status'] == StatusRequest.success) {
      var data = branchRes['data'];
      if (data is Map && data['data'] is Map) data = data['data'];
      if (data is Map && data['branches'] != null) {
        branches = (data['branches'] as List)
            .map((e) => BranchModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (data is List) {
        branches = data
            .map((e) => BranchModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    final shiftRes = await _shiftData.getShifts();
    if (shiftRes['status'] == StatusRequest.success) {
      final data = shiftRes['data'];
      dynamic payload = data;
      if (payload is Map && payload['data'] != null) payload = payload['data'];
      List<dynamic>? items;
      if (payload is List) {
        items = payload;
      } else if (payload is Map) {
        for (final key in const ['items', 'records', 'list', 'data']) {
          if (payload[key] is List) {
            items = payload[key] as List;
            break;
          }
        }
      }
      if (items != null) {
        shifts = items
            .whereType<Map<String, dynamic>>()
            .map(ShiftModel.fromJson)
            .toList();
      }
    }

    final catRes = await _categoryData.getCategories();
    if (catRes['status'] == StatusRequest.success) {
      dynamic body = catRes['data'];
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
    }

    update();
  }

  List<EmployeeModel> _extractItems(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) {
      payload = payload['data'];
    }
    List<dynamic>? items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      for (final key in const ['items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          items = payload[key] as List;
          break;
        }
      }
    }
    if (items == null) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(EmployeeModel.fromJson)
        .toList();
  }

  void onSearch(String query) {
    searchQuery = query;
    loadEmployees();
  }

  void applyFilters({int? branchId, int? shiftId, int? categoryId}) {
    branchFilter = branchId;
    shiftFilter = shiftId;
    categoryFilter = categoryId;
    loadEmployees();
  }

  void clearFilters() {
    branchFilter = null;
    shiftFilter = null;
    categoryFilter = null;
    loadEmployees();
  }

  bool get hasActiveFilters =>
      branchFilter != null || shiftFilter != null || categoryFilter != null;

  String? branchName(int? id) {
    if (id == null) return null;
    for (final b in branches) {
      if (b.id == id) return b.name;
    }
    return null;
  }

  String? shiftName(int? id) {
    if (id == null) return null;
    for (final s in shifts) {
      if (s.id == id) return s.name;
    }
    return null;
  }

  String? categoryName(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return null;
  }
}
