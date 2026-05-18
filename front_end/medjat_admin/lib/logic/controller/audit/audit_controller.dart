import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/audit_data/audit_data.dart';
import '../../../data/model/audit_log_model.dart';

class AuditController extends GetxController {
  final AuditData _auditData = Get.find<AuditData>();

  final status = StatusRequest.none.obs;
  final logs = <AuditLogModel>[].obs;
  final currentPage = 1.obs;

  @override
  void onInit() {
    super.onInit();
    loadLogs();
  }

  Future<void> loadLogs({int? page}) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _auditData.list(page: page ?? currentPage.value);

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        final items = (data['items'] as List<dynamic>?)
                ?.map((e) => AuditLogModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        logs.value = items;
        currentPage.value = data['page'] as int? ?? 1;
      }
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }
}
