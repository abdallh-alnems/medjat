import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/station_data/station_data.dart';
import '../../../data/model/station_recognition_log_model.dart';

class RecognitionLogsController extends GetxController {
  final StationData _data = Get.find<StationData>();

  StatusRequest status = StatusRequest.none;
  List<StationRecognitionLogModel> logs = [];
  int total = 0;
  int page = 1;
  int limit = 20;

  int? filterBranchId;
  int? filterStationId;
  int? filterEmployeeId;
  String? filterResult;
  String? filterFrom;
  String? filterTo;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final filters = <String, dynamic>{};
    if (filterBranchId != null) filters['branch_id'] = filterBranchId;
    if (filterStationId != null) filters['station_id'] = filterStationId;
    if (filterEmployeeId != null) filters['employee_id'] = filterEmployeeId;
    if (filterResult != null) filters['result'] = filterResult;
    if (filterFrom != null) filters['from'] = filterFrom;
    if (filterTo != null) filters['to'] = filterTo;
    filters['page'] = page;

    final response = await _data.getLogs(filters: filters);
    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is Map) {
        total = (payload['total'] as int?) ?? 0;
        page = (payload['page'] as int?) ?? 1;
        final items = payload['items'] as List? ?? [];
        logs = items
            .whereType<Map<String, dynamic>>()
            .map((e) => StationRecognitionLogModel.fromJson(e))
            .toList();
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  void setPage(int p) {
    page = p;
    load();
  }

  void setFilters({
    int? branchId,
    int? stationId,
    int? employeeId,
    String? result,
    String? from,
    String? to,
  }) {
    filterBranchId = branchId;
    filterStationId = stationId;
    filterEmployeeId = employeeId;
    filterResult = result;
    filterFrom = from;
    filterTo = to;
    page = 1;
    load();
  }
}
