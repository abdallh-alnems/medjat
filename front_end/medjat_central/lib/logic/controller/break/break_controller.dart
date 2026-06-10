import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/break_data/break_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/model/break_request_model.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/employee_category_model.dart';

class BreakController extends GetxController {
  final BreakData _breakData = Get.find<BreakData>();
  final BranchData _branchData = Get.find<BranchData>();
  final CategoryData _categoryData = Get.find<CategoryData>();

  StatusRequest status = StatusRequest.none;
  List<BreakRequestModel> breaks = [];
  String? statusFilter;

  // Branch / category / employee-name filters.
  List<BranchModel> branches = [];
  List<EmployeeCategoryModel> categories = [];
  int? branchFilter;
  int? categoryFilter;
  String searchQuery = '';
  final TextEditingController searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    loadFilterOptions();
    loadBreaks();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    searchCtrl.dispose();
    super.onClose();
  }

  Future<void> loadBreaks() async {
    status = StatusRequest.loading;
    update();

    final response = await _breakData.getBreaks(
      status: statusFilter,
      branchId: branchFilter,
      categoryId: categoryFilter,
      search: searchQuery,
    );

    if (response['status'] == StatusRequest.success) {
      breaks = _extractItems(response['data']);
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
      if (data is Map && data['branches'] is List) {
        branches = (data['branches'] as List)
            .map((e) => BranchModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (data is List) {
        branches = data
            .map((e) => BranchModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    final catRes = await _categoryData.getCategories();
    if (catRes['status'] == StatusRequest.success) {
      dynamic body = catRes['data'];
      if (body is Map && body['data'] is Map) body = body['data'];
      if (body is Map && body['categories'] is List) {
        categories = (body['categories'] as List)
            .map((e) => EmployeeCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (body is List) {
        categories = body
            .map((e) => EmployeeCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    update();
  }

  void filterByBranch(int? branchId) {
    branchFilter = branchId;
    loadBreaks();
  }

  void filterByCategory(int? categoryId) {
    categoryFilter = categoryId;
    loadBreaks();
  }

  void search(String query) {
    searchQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), loadBreaks);
  }

  void clearFilters() {
    branchFilter = null;
    categoryFilter = null;
    searchQuery = '';
    searchCtrl.clear();
    loadBreaks();
  }

  List<BreakRequestModel> _extractItems(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) {
      payload = payload['data'];
    }
    List<dynamic>? items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      for (final key in const ['breaks', 'items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          items = payload[key] as List;
          break;
        }
      }
    }
    if (items == null) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(BreakRequestModel.fromJson)
        .toList();
  }

  void filterByStatus(String? status) {
    statusFilter = status;
    loadBreaks();
  }

  Future<void> approveBreak(int id, {bool? deductFromSalary}) async {
    final response =
        await _breakData.approveBreak(id, deductFromSalary: deductFromSalary);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'break_approved'.tr, snackPosition: SnackPosition.BOTTOM);
      loadBreaks();
    }
  }

  Future<void> rejectBreak(int id, {String? reason}) async {
    final response = await _breakData.rejectBreak(id, reason: reason);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'break_rejected'.tr, snackPosition: SnackPosition.BOTTOM);
      loadBreaks();
    }
  }

  Future<void> postponeBreak(
    int id, {
    String? note,
    String? suggestedDate,
    String? suggestedStartTime,
    String? suggestedEndTime,
  }) async {
    final response = await _breakData.postponeBreak(
      id,
      note: note,
      suggestedDate: suggestedDate,
      suggestedStartTime: suggestedStartTime,
      suggestedEndTime: suggestedEndTime,
    );
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'break_postponed'.tr, snackPosition: SnackPosition.BOTTOM);
      loadBreaks();
    }
  }

  Future<bool> createBreak({
    required int employeeId,
    required String date,
    required String startTime,
    required String endTime,
    required String type,
    String? reason,
    bool deductFromSalary = false,
  }) async {
    final data = <String, dynamic>{
      'employee_id': employeeId,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'type': type,
      'deduct_from_salary': deductFromSalary ? 1 : 0,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      data['reason'] = reason.trim();
    }

    final response = await _breakData.createBreak(data);

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'break_created_success'.tr, snackPosition: SnackPosition.BOTTOM);
      loadBreaks();
      return true;
    }

    if (response['statusCode'] == 409) {
      final msg = response['message'];
      Get.snackbar('error'.tr, msg is String ? msg : 'break_overlap'.tr, snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    final errMsg = response['message'];
    Get.snackbar('error'.tr, errMsg is String ? errMsg : 'break_created_failed'.tr, snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  Future<void> cancelBreak(int id) async {
    final response = await _breakData.cancelBreak(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'break_cancelled'.tr, snackPosition: SnackPosition.BOTTOM);
      loadBreaks();
    }
  }
}
