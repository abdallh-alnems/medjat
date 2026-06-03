import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String? activationToken;
  String? joinLink;
  String? employeePhone;
  String? employeeName;
  int? createdEmployeeId;
  int? selectedBranchId;
  int? selectedShiftId;
  int? selectedCategoryId;
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

    employeeName = (data['name'] as String?)?.trim();
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
        activationToken = payload['activation_token'] as String?;
        joinLink = payload['join_link'] as String?;
        employeePhone = payload['phone'] as String?;
      }
      // Fall back to the phone submitted in the form if the API didn't echo it.
      if (employeePhone == null || employeePhone!.isEmpty) {
        employeePhone = (data['phone'] as String?)?.trim();
      }

      status.value = StatusRequest.success;
      update();

      if (activationCode == null) {
        Get.back(result: true);
        Future.delayed(const Duration(milliseconds: 250), () {
          Get.snackbar(
            'done'.tr,
            'employee_added_success'.tr,
            snackPosition: SnackPosition.BOTTOM,
          );
        });
        return;
      }

      Get.snackbar(
        'done'.tr,
        'employee_added_success'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      status.value = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
      final message = (response['message'] as String?) ?? 'error_try_again'.tr;
      Get.snackbar('error'.tr, message, snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  /// Opens WhatsApp pre-filled with the employee's login phone + activation
  /// code so the admin can hand off both in one message. Targets the employee's
  /// own number when available, otherwise opens the WhatsApp picker.
  Future<void> shareViaWhatsApp() async {
    final code = activationCode;
    if (code == null || code.isEmpty) return;

    final message = 'activation_code_share_message'.trParams({
      'code': code,
      'employee_name': employeeName ?? '',
      'phone': employeePhone ?? '',
    });

    final encoded = Uri.encodeComponent(message);
    final normalizedPhone = employeePhone?.replaceAll(RegExp(r'[^0-9]'), '');

    final uri = normalizedPhone != null && normalizedPhone.isNotEmpty
        ? Uri.parse('https://wa.me/$normalizedPhone?text=$encoded')
        : Uri.parse('https://wa.me/?text=$encoded');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      Get.snackbar('error'.tr, 'cannot_open_whatsapp'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
