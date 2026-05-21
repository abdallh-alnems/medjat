import 'dart:io';
import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class LetterData {
  final CRUD _crud = Get.find<CRUD>();

  // ── Templates ──────────────────────────────────────────
  Future<Map<String, dynamic>> getTemplates() async {
    return await _crud.getData(AppLinks.letterTemplates);
  }

  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.letterTemplateCreate, data);
  }

  Future<Map<String, dynamic>> updateTemplate(
      int id, Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.letterTemplateUpdate, {
      'template_id': id,
      ...data,
    });
  }

  Future<Map<String, dynamic>> deleteTemplate(int id) async {
    return await _crud.postData(AppLinks.letterTemplateDelete(id), {
      'template_id': id,
    });
  }

  // ── Requests ───────────────────────────────────────────
  Future<Map<String, dynamic>> getRequests({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    return await _crud.getData(AppLinks.letterRequests,
        queryParameters: params);
  }

  Future<Map<String, dynamic>> issueDocument({
    required int employeeId,
    required int templateId,
    Map<String, String>? extraFields,
  }) async {
    return await _crud.postData(AppLinks.letterRequestCreate, {
      'employee_id': employeeId,
      'template_id': templateId,
      if (extraFields != null && extraFields.isNotEmpty)
        'extra_fields': extraFields,
    });
  }

  Future<Map<String, dynamic>> approveRequest(int id,
      {Map<String, String>? extraFields}) async {
    return await _crud.postData(AppLinks.letterRequestApprove(id), {
      'request_id': id,
      if (extraFields != null && extraFields.isNotEmpty)
        'extra_fields': extraFields,
    });
  }

  Future<Map<String, dynamic>> rejectRequest(int id, {String? reason}) async {
    return await _crud.postData(AppLinks.letterRequestReject(id), {
      'request_id': id,
      if (reason != null) 'rejection_reason': reason,
    });
  }

  Future<Map<String, dynamic>> downloadPdf(int id) async {
    return await _crud.getBytes(AppLinks.letterRequestPdf(id));
  }

  // ── Company branding upload (logo/stamp/signature) ─────
  Future<Map<String, dynamic>> uploadBranding(String type, File file) async {
    return await _crud.postFile(
      AppLinks.companyUploadBranding,
      file,
      fields: {'type': type},
    );
  }
}
