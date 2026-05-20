import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/document_reports_data/document_reports_data.dart';
import '../../../data/model/document_report_model.dart';
import '../../../data/model/document_stats_model.dart';

class DocumentReportsController extends GetxController {
  final DocumentReportsData _data = Get.find<DocumentReportsData>();

  StatusRequest statsStatus = StatusRequest.none;
  StatusRequest missingStatus = StatusRequest.none;
  StatusRequest expiringStatus = StatusRequest.none;
  StatusRequest expiredStatus = StatusRequest.none;

  DocumentStatsModel? stats;
  List<DocumentReportModel> missingDocuments = [];
  List<DocumentReportModel> expiringDocuments = [];
  List<DocumentReportModel> expiredDocuments = [];

  int selectedTabIndex = 0;
  int? filterBranchId;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait([
      loadStats(),
      loadMissing(),
      loadExpiringSoon(),
      loadExpired(),
    ]);
  }

  void setTab(int index) {
    selectedTabIndex = index;
    update();
  }

  void setBranchFilter(int? branchId) {
    filterBranchId = branchId;
    loadAll();
  }

  Future<void> loadStats() async {
    statsStatus = StatusRequest.loading;
    update();

    final response = await _data.getStats();

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) {
        body = body['data'];
      }
      if (body is Map && body['stats'] is Map) {
        stats = DocumentStatsModel.fromJson(
            body['stats'] as Map<String, dynamic>);
      }
      statsStatus = StatusRequest.success;
    } else {
      statsStatus = StatusRequest.failure;
    }
    update();
  }

  Future<void> loadMissing() async {
    missingStatus = StatusRequest.loading;
    update();

    final response = await _data.getMissing(branchId: filterBranchId);

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) {
        body = body['data'];
      }
      if (body is Map && body['missing_documents'] is List) {
        missingDocuments = (body['missing_documents'] as List)
            .map((e) =>
                DocumentReportModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (body is List) {
        missingDocuments = body
            .map((e) =>
                DocumentReportModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      missingStatus = StatusRequest.success;
    } else {
      missingStatus = StatusRequest.failure;
    }
    update();
  }

  Future<void> loadExpiringSoon() async {
    expiringStatus = StatusRequest.loading;
    update();

    final response =
        await _data.getExpiringSoon(branchId: filterBranchId);

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) {
        body = body['data'];
      }
      if (body is Map && body['documents'] is List) {
        expiringDocuments = (body['documents'] as List)
            .map((e) =>
                DocumentReportModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (body is List) {
        expiringDocuments = body
            .map((e) =>
                DocumentReportModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      expiringStatus = StatusRequest.success;
    } else {
      expiringStatus = StatusRequest.failure;
    }
    update();
  }

  Future<void> loadExpired() async {
    expiredStatus = StatusRequest.loading;
    update();

    final response = await _data.getExpired(branchId: filterBranchId);

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) {
        body = body['data'];
      }
      if (body is Map && body['documents'] is List) {
        expiredDocuments = (body['documents'] as List)
            .map((e) =>
                DocumentReportModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (body is List) {
        expiredDocuments = body
            .map((e) =>
                DocumentReportModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      expiredStatus = StatusRequest.success;
    } else {
      expiredStatus = StatusRequest.failure;
    }
    update();
  }
}
