import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/letter_data/letter_data.dart';
import '../../../data/model/document_template_model.dart';

class LetterTemplateController extends GetxController {
  final LetterData _data = Get.find<LetterData>();

  StatusRequest status = StatusRequest.none;
  List<DocumentTemplateModel> templates = [];
  List<String> variables = [];

  @override
  void onInit() {
    super.onInit();
    loadTemplates();
  }

  List<DocumentTemplateModel> get activeTemplates =>
      templates.where((t) => t.isActive).toList();

  Future<void> loadTemplates() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getTemplates();

    if (response['status'] == StatusRequest.success) {
      final body = response['data'];
      final payload = body is Map && body['data'] is Map ? body['data'] : body;
      final rawList = (payload is Map ? payload['templates'] : null);
      if (rawList is List) {
        templates = rawList
            .whereType<Map<String, dynamic>>()
            .map(DocumentTemplateModel.fromJson)
            .toList();
      } else {
        templates = [];
      }
      final rawVars = (payload is Map ? payload['variables'] : null);
      if (rawVars is List) {
        variables = rawVars.map((e) => e.toString()).toList();
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<bool> saveTemplate({
    int? id,
    required String nameAr,
    String? nameEn,
    required String bodyAr,
    bool isActive = true,
  }) async {
    final data = <String, dynamic>{
      'name_ar': nameAr.trim(),
      if (nameEn != null && nameEn.trim().isNotEmpty) 'name_en': nameEn.trim(),
      'body_ar': bodyAr.trim(),
      'is_active': isActive ? 1 : 0,
    };

    final response = id == null
        ? await _data.createTemplate(data)
        : await _data.updateTemplate(id, data);

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'template_saved'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadTemplates();
      return true;
    }
    _showError(response, 'template_save_failed'.tr);
    return false;
  }

  Future<void> toggleActive(DocumentTemplateModel tpl) async {
    final response = await _data.updateTemplate(tpl.id, {
      'is_active': tpl.isActive ? 0 : 1,
    });
    if (response['status'] == StatusRequest.success) {
      loadTemplates();
    } else {
      _showError(response, 'template_save_failed'.tr);
    }
  }

  Future<void> deleteTemplate(DocumentTemplateModel tpl) async {
    if (tpl.isSystem) {
      Get.snackbar('error'.tr, 'template_system_no_delete'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('confirm_delete'.tr),
        content: Text('template_delete_confirm'.trParams({'name': tpl.displayName})),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back<bool>(result: true),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final response = await _data.deleteTemplate(tpl.id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'template_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadTemplates();
    } else {
      _showError(response, 'template_save_failed'.tr);
    }
  }

  void _showError(Map<String, dynamic> response, String fallback) {
    final msg = response['message'];
    Get.snackbar('error'.tr, msg is String ? msg : fallback,
        snackPosition: SnackPosition.BOTTOM);
  }
}
