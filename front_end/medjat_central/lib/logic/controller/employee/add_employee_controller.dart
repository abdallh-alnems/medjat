import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/shift_data/shift_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/shift_model.dart';
import '../../../data/model/employee_category_model.dart';

class AddEmployeeController extends GetxController {
  final EmployeeData _employeeData = Get.find<EmployeeData>();
  final BranchData _branchData = Get.find<BranchData>();
  final ShiftData _shiftData = Get.find<ShiftData>();
  final CategoryData _categoryData = Get.find<CategoryData>();

  final status = StatusRequest.none.obs;
  bool branchesLoading = true;
  List<BranchModel> branches = [];
  List<ShiftModel> shifts = [];
  List<EmployeeCategoryModel> categories = [];

  String? activationCode;
  int? createdEmployeeId;
  int? selectedBranchId;
  int? selectedShiftId;
  final Set<int> selectedCategoryIds = {};
  TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

  void setStartTime(TimeOfDay t) {
    startTime = t;
    update();
  }

  void setEndTime(TimeOfDay t) {
    endTime = t;
    update();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String get workStartTimeStr => _formatTime(startTime);
  String get workEndTimeStr => _formatTime(endTime);

  @override
  void onInit() {
    super.onInit();
    loadBranches();
    loadShifts();
    loadCategories();
  }

  Future<void> loadBranches() async {
    branchesLoading = true;
    update();
    final response = await _branchData.getBranches();
    if (response['status'] == StatusRequest.success) {
      var data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map && data['branches'] != null) {
        branches = (data['branches'] as List)
            .map((e) => BranchModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (data is List) {
        branches =
            data.map((e) => BranchModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    branchesLoading = false;
    update();
  }

  Future<void> loadShifts() async {
    final response = await _shiftData.getShifts();
    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
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

  Future<void> createEmployee(Map<String, dynamic> data) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _employeeData.createEmployee(data);

    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) {
        payload = payload['data'];
      }
      if (payload is Map) {
        createdEmployeeId = (payload['employee_id'] as num?)?.toInt() ??
            (payload['employee'] is Map
                ? (payload['employee']['id'] as num?)?.toInt()
                : null);
        activationCode = payload['activation_code'] as String?;
      }

      status.value = StatusRequest.success;
      update();

      if (activationCode == null) {
        Get.back(result: true);
        Future.delayed(const Duration(milliseconds: 250), () {
          Get.snackbar(
            'تم',
            'تم إضافة الموظف بنجاح',
            snackPosition: SnackPosition.BOTTOM,
          );
        });
        return;
      }

      Get.snackbar(
        'تم',
        'تم إضافة الموظف بنجاح',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      status.value = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
      final message = (response['message'] as String?) ?? 'حدث خطأ، حاول مرة أخرى';
      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }
}
