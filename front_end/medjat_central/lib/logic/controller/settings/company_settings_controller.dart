import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/company_settings_data/company_settings_data.dart';

class CompanySettingsController extends GetxController {
  final CompanySettingsData _companySettingsData =
      Get.find<CompanySettingsData>();

  StatusRequest status = StatusRequest.none;
  Map<String, dynamic> companyData = {};

  final nameController = TextEditingController();
  final commercialRegisterController = TextEditingController();

  // Localization preferences (sent to the backend on save).
  String currency = 'EGP';
  String timezone = 'Africa/Cairo';

  // Whether each letterhead asset has been uploaded (drives the UI state).
  bool hasLogo = false;
  bool hasStamp = false;
  bool hasSignature = false;

  // The branding asset currently uploading (logo/stamp/signature), or null.
  String? uploadingType;

  // Company default attendance cycle start day (1-28). Branches may override.
  int cycleStartDay = 1;

  // Weekly-schedule start weekday (ISO: 1=Mon..7=Sun, default 6=Sat).
  int weekStartDay = 6;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  @override
  void onClose() {
    nameController.dispose();
    commercialRegisterController.dispose();
    super.onClose();
  }

  Future<void> loadSettings() async {
    status = StatusRequest.loading;
    update();

    final response = await _companySettingsData.getCompanySettings();

    if (response['status'] == StatusRequest.success) {
      // Unwrap the API envelope: {status, data:{...}}.
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map<String, dynamic>) {
        companyData = data;
        nameController.text = (data['name'] as String?) ?? '';
        commercialRegisterController.text =
            (data['commercial_register'] as String?) ?? '';
        currency = (data['currency'] as String?)?.toUpperCase() ?? 'EGP';
        timezone = (data['timezone'] as String?) ?? 'Africa/Cairo';
        hasLogo = data['has_logo'] == true;
        hasStamp = data['has_stamp'] == true;
        hasSignature = data['has_signature'] == true;
        cycleStartDay = (data['cycle_start_day'] as num?)?.toInt() ?? 1;
        weekStartDay = (data['week_start_day'] as num?)?.toInt() ?? 6;
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void setCycleStartDay(int day) {
    cycleStartDay = day.clamp(1, 28);
    update();
  }

  void setWeekStartDay(int weekday) {
    weekStartDay = weekday.clamp(1, 7);
    update();
  }

  void setCurrency(String value) {
    currency = value;
    update();
  }

  void setTimezone(String value) {
    timezone = value;
    update();
  }

  Future<void> saveSettings() async {
    status = StatusRequest.loading;
    update();

    final data = {
      'name': nameController.text.trim(),
      'commercial_register': commercialRegisterController.text.trim(),
      'currency': currency,
      'timezone': timezone,
      'cycle_start_day': cycleStartDay.clamp(1, 28),
      'week_start_day': weekStartDay.clamp(1, 7),
    };

    final response = await _companySettingsData.updateCompanySettings(data);

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'company_data_saved'.tr,
          snackPosition: SnackPosition.BOTTOM);
      status = StatusRequest.success;
    } else {
      Get.snackbar(
          'error'.tr, (response['message'] as String?) ?? 'an_error_occurred'.tr,
          snackPosition: SnackPosition.BOTTOM);
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  /// Uploads a branding asset ([type] = logo/stamp/signature) and reflects the
  /// new state in the UI on success.
  Future<void> uploadBranding(String type, File file) async {
    uploadingType = type;
    update();

    final response = await _companySettingsData.uploadBranding(type, file);

    if (response['status'] == StatusRequest.success) {
      switch (type) {
        case 'logo':
          hasLogo = true;
          break;
        case 'stamp':
          hasStamp = true;
          break;
        case 'signature':
          hasSignature = true;
          break;
      }
      Get.snackbar('done'.tr, 'branding_uploaded'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar(
          'error'.tr, (response['message'] as String?) ?? 'an_error_occurred'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    uploadingType = null;
    update();
  }
}
