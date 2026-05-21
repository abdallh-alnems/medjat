import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/company_settings_data/company_settings_data.dart';

class LeaveSettingsController extends GetxController {
  final CompanySettingsData _data = Get.find<CompanySettingsData>();

  StatusRequest status = StatusRequest.none;
  bool saving = false;
  bool rolloverRunning = false;

  final defaultDaysController = TextEditingController();
  final carryoverDaysController = TextEditingController();

  /// When false, remaining balance is dropped at year end (no carryover).
  bool carryoverEnabled = false;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  @override
  void onClose() {
    defaultDaysController.dispose();
    carryoverDaysController.dispose();
    super.onClose();
  }

  Future<void> loadSettings() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getLeaveSettings();

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) body = body['data'];
      if (body is Map) {
        final defaultDays = (body['default_annual_leave_days'] as num?)?.toInt() ?? 21;
        defaultDaysController.text = defaultDays.toString();
        final carryover = (body['leave_carryover_max_days'] as num?)?.toInt();
        carryoverEnabled = carryover != null;
        carryoverDaysController.text = carryover?.toString() ?? '';
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void setCarryoverEnabled(bool value) {
    carryoverEnabled = value;
    update();
  }

  Future<void> saveSettings() async {
    final defaultDays = int.tryParse(defaultDaysController.text.trim());
    if (defaultDays == null || defaultDays < 0 || defaultDays > 366) {
      Get.snackbar('error'.tr, 'leave_default_days_invalid'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    int? carryoverMax;
    if (carryoverEnabled) {
      carryoverMax = int.tryParse(carryoverDaysController.text.trim());
      if (carryoverMax == null || carryoverMax < 0 || carryoverMax > 366) {
        Get.snackbar('error'.tr, 'leave_carryover_days_invalid'.tr,
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
    }

    saving = true;
    update();

    final response = await _data.updateLeaveSettings(
      defaultAnnualLeaveDays: defaultDays,
      carryoverMaxDays: carryoverMax,
    );

    saving = false;
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'leave_settings_saved'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('error'.tr,
          (response['message'] as String?) ?? 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> runRollover(int fromYear) async {
    rolloverRunning = true;
    update();

    final response = await _data.runLeaveRollover(fromYear);

    rolloverRunning = false;
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr,
          'leave_rollover_done'.trParams({'year': (fromYear + 1).toString()}),
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('error'.tr,
          (response['message'] as String?) ?? 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }
}
