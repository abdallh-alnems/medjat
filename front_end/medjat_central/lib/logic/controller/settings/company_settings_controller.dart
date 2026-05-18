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
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  @override
  void onClose() {
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    super.onClose();
  }

  Future<void> loadSettings() async {
    status = StatusRequest.loading;
    update();

    final response = await _companySettingsData.getCompanySettings();

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        companyData = data;
        nameController.text = (data['name'] as String?) ?? '';
        addressController.text = (data['address'] as String?) ?? '';
        phoneController.text = (data['phone'] as String?) ?? '';
        emailController.text = (data['email'] as String?) ?? '';
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> saveSettings() async {
    status = StatusRequest.loading;
    update();

    final data = {
      'name': nameController.text.trim(),
      'address': addressController.text.trim(),
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
    };

    final response = await _companySettingsData.updateCompanySettings(data);

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم حفظ بيانات الشركة',
          snackPosition: SnackPosition.BOTTOM);
      status = StatusRequest.success;
    } else {
      Get.snackbar(
          'خطأ', (response['message'] as String?) ?? 'حدث خطأ',
          snackPosition: SnackPosition.BOTTOM);
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }
}
