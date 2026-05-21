import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/letter_data/letter_data.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/document_request_model.dart';
import '../../../data/model/employee_model.dart';

class LetterRequestController extends GetxController {
  final LetterData _data = Get.find<LetterData>();
  final EmployeeData _employeeData = Get.find<EmployeeData>();

  StatusRequest status = StatusRequest.none;
  List<DocumentRequestModel> requests = [];
  String? statusFilter;

  List<EmployeeModel> employees = [];
  bool employeesLoading = false;

  bool actionLoading = false;

  @override
  void onInit() {
    super.onInit();
    loadRequests();
  }

  Future<void> loadRequests() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getRequests(status: statusFilter);

    if (response['status'] == StatusRequest.success) {
      requests = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void filterByStatus(String? value) {
    statusFilter = value;
    loadRequests();
  }

  List<DocumentRequestModel> _extractItems(dynamic raw) {
    dynamic payload = raw;
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
    if (items == null) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(DocumentRequestModel.fromJson)
        .toList();
  }

  Future<void> loadEmployees() async {
    if (employees.isNotEmpty) return;
    employeesLoading = true;
    update();
    final response = await _employeeData.getEmployees();
    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] != null) payload = payload['data'];
      List<dynamic>? raw;
      if (payload is List) {
        raw = payload;
      } else if (payload is Map) {
        for (final key in const ['items', 'employees', 'records', 'list']) {
          if (payload[key] is List) {
            raw = payload[key] as List;
            break;
          }
        }
      }
      employees = (raw ?? [])
          .whereType<Map<String, dynamic>>()
          .map(EmployeeModel.fromJson)
          .toList();
    }
    employeesLoading = false;
    update();
  }

  Future<bool> issueDocument({
    required int employeeId,
    required int templateId,
    Map<String, String>? extraFields,
  }) async {
    actionLoading = true;
    update();
    final response = await _data.issueDocument(
      employeeId: employeeId,
      templateId: templateId,
      extraFields: extraFields,
    );
    actionLoading = false;
    update();

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'letter_issued'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadRequests();
      return true;
    }
    _showError(response, 'letter_issue_failed'.tr);
    return false;
  }

  Future<void> approveRequest(int id, {Map<String, String>? extraFields}) async {
    final response = await _data.approveRequest(id, extraFields: extraFields);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'letter_issued'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadRequests();
    } else {
      _showError(response, 'letter_issue_failed'.tr);
    }
  }

  Future<void> rejectRequest(int id, {String? reason}) async {
    final response = await _data.rejectRequest(id, reason: reason);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'letter_rejected'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadRequests();
    } else {
      _showError(response, 'letter_issue_failed'.tr);
    }
  }

  /// Fetches the generated PDF and opens the native print/share preview.
  Future<void> openPdf(DocumentRequestModel request) async {
    Get.snackbar('loading'.tr, '',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1));
    final response = await _data.downloadPdf(request.id);
    if (response['status'] == StatusRequest.success &&
        response['bytes'] is Uint8List) {
      final bytes = response['bytes'] as Uint8List;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'document_${request.id}.pdf',
      );
    } else {
      Get.snackbar('error'.tr, 'letter_pdf_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showError(Map<String, dynamic> response, String fallback) {
    final msg = response['message'];
    Get.snackbar('error'.tr, msg is String ? msg : fallback,
        snackPosition: SnackPosition.BOTTOM);
  }
}
