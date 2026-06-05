import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';

class ExportTemplateController extends GetxController {
  final PayrollData _payrollData = Get.find<PayrollData>();

  StatusRequest status = StatusRequest.none;
  List<Map<String, dynamic>> templates = [];
  List<Map<String, dynamic>> fields = [];

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    status = StatusRequest.loading;
    update();
    await Future.wait([loadTemplates(), loadFields()]);
    status = StatusRequest.success;
    update();
  }

  Future<void> loadTemplates() async {
    final response = await _payrollData.listExportTemplates();
    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is Map && data['templates'] is List) {
        templates = (data['templates'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }
  }

  Future<void> loadFields() async {
    final response = await _payrollData.getExportFields();
    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is Map && data['fields'] is List) {
        fields = (data['fields'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    }
  }

  Future<bool> createTemplate({
    required String name,
    required String delimiter,
    required int includeBom,
    required int includeHeaderRow,
    required int decimalPlaces,
    required List<Map<String, String>> columns,
  }) async {
    final response = await _payrollData.createExportTemplate(
      name: name,
      delimiter: delimiter,
      includeBom: includeBom,
      includeHeaderRow: includeHeaderRow,
      decimalPlaces: decimalPlaces,
      columns: columns,
    );
    if (response['status'] == StatusRequest.success) {
      await loadTemplates();
      return true;
    }
    return false;
  }

  Future<bool> updateTemplate({
    required int id,
    String? name,
    String? delimiter,
    int? includeBom,
    int? includeHeaderRow,
    int? decimalPlaces,
    List<Map<String, String>>? columns,
  }) async {
    final response = await _payrollData.updateExportTemplate(
      id: id,
      name: name,
      delimiter: delimiter,
      includeBom: includeBom,
      includeHeaderRow: includeHeaderRow,
      decimalPlaces: decimalPlaces,
      columns: columns,
    );
    if (response['status'] == StatusRequest.success) {
      await loadTemplates();
      return true;
    }
    return false;
  }

  Future<bool> deleteTemplate(int id) async {
    final response = await _payrollData.deleteExportTemplate(id);
    if (response['status'] == StatusRequest.success) {
      await loadTemplates();
      return true;
    }
    return false;
  }
}
