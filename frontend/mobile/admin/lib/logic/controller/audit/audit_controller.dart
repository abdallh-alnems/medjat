import 'dart:async';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/audit_data/audit_data.dart';
import '../../../data/model/audit_log_model.dart';

class AuditController extends GetxController {
  final AuditData _auditData = Get.find<AuditData>();

  final status = StatusRequest.none.obs;
  final logs = <AuditLogModel>[].obs;
  final currentPage = 1.obs;
  final totalPages = 1.obs;
  final total = 0.obs;
  final actionFilter = ''.obs;
  final searchQuery = ''.obs;

  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    loadLogs();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  Future<void> loadLogs({int? page}) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _auditData.list(
      page: page ?? currentPage.value,
      action: actionFilter.value,
      q: searchQuery.value,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        logs.value = (data['items'] as List<dynamic>?)
                ?.map((e) => AuditLogModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        currentPage.value = data['page'] as int? ?? 1;
        totalPages.value = data['total_pages'] as int? ?? 1;
        total.value = data['total'] as int? ?? logs.length;
      }
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }

  void setActionFilter(String value) {
    actionFilter.value = value;
    currentPage.value = 1;
    loadLogs(page: 1);
  }

  void onSearchChanged(String value) {
    searchQuery.value = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      currentPage.value = 1;
      loadLogs(page: 1);
    });
  }

  bool get hasNextPage => currentPage.value < totalPages.value;
  bool get hasPreviousPage => currentPage.value > 1;

  void nextPage() {
    if (hasNextPage) loadLogs(page: currentPage.value + 1);
  }

  void previousPage() {
    if (hasPreviousPage) loadLogs(page: currentPage.value - 1);
  }
}
