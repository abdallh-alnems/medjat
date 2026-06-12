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
  final expiryMonthsController = TextEditingController();
  final legalMinController = TextEditingController();

  /// When false, remaining balance is dropped at year end (no carryover).
  bool carryoverEnabled = false;

  /// Carried days expire after [expiryMonthsController] months when true.
  bool expiryEnabled = false;

  /// Pay out (cash) days above the cap instead of dropping them.
  bool encashExcess = false;

  /// Cron runs the year-end rollover automatically on Jan 1.
  bool autoRolloverEnabled = false;

  /// Bump entitlement to >=30 days after 10 years service (Egyptian law).
  bool applyLegalSeniority = true;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  @override
  void onClose() {
    defaultDaysController.dispose();
    carryoverDaysController.dispose();
    expiryMonthsController.dispose();
    legalMinController.dispose();
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
        final defaultDays = (body['default_annual_leave_days'] as num?)?.toInt() ?? 0;
        defaultDaysController.text = defaultDays.toString();
        final carryover = (body['leave_carryover_max_days'] as num?)?.toInt();
        carryoverEnabled = (body['carryover_enabled'] as bool?) ?? (carryover != null);
        carryoverDaysController.text = carryover?.toString() ?? '';

        final expiry = (body['carryover_expiry_months'] as num?)?.toInt();
        expiryEnabled = expiry != null;
        expiryMonthsController.text = expiry?.toString() ?? '';

        encashExcess = (body['carryover_encash_excess'] as bool?) ?? false;

        final legalMin = (body['carryover_legal_min_days'] as num?)?.toInt();
        legalMinController.text = legalMin?.toString() ?? '';

        autoRolloverEnabled = (body['auto_rollover_enabled'] as bool?) ?? false;
        applyLegalSeniority =
            (body['apply_legal_seniority_entitlement'] as bool?) ?? true;
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

  void setExpiryEnabled(bool value) {
    expiryEnabled = value;
    update();
  }

  void setEncashExcess(bool value) {
    encashExcess = value;
    update();
  }

  void setAutoRollover(bool value) {
    autoRolloverEnabled = value;
    update();
  }

  void setApplyLegalSeniority(bool value) {
    applyLegalSeniority = value;
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
    int? expiryMonths;
    int? legalMin;
    if (carryoverEnabled) {
      carryoverMax = int.tryParse(carryoverDaysController.text.trim());
      if (carryoverMax == null || carryoverMax < 0 || carryoverMax > 366) {
        Get.snackbar('error'.tr, 'leave_carryover_days_invalid'.tr,
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (expiryEnabled) {
        expiryMonths = int.tryParse(expiryMonthsController.text.trim());
        if (expiryMonths == null || expiryMonths < 0 || expiryMonths > 60) {
          Get.snackbar('error'.tr, 'leave_expiry_invalid'.tr,
              snackPosition: SnackPosition.BOTTOM);
          return;
        }
      }
      final legalText = legalMinController.text.trim();
      if (legalText.isNotEmpty) {
        legalMin = int.tryParse(legalText);
        if (legalMin == null || legalMin < 0 || legalMin > 366) {
          Get.snackbar('error'.tr, 'leave_legal_min_invalid'.tr,
              snackPosition: SnackPosition.BOTTOM);
          return;
        }
      }
    }

    saving = true;
    update();

    final response = await _data.updateLeaveSettings(
      defaultAnnualLeaveDays: defaultDays,
      carryoverEnabled: carryoverEnabled,
      carryoverMaxDays: carryoverMax,
      expiryMonths: expiryMonths,
      encashExcess: carryoverEnabled && encashExcess,
      legalMinDays: legalMin,
      autoRolloverEnabled: autoRolloverEnabled,
      applyLegalSeniorityEntitlement: applyLegalSeniority,
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
