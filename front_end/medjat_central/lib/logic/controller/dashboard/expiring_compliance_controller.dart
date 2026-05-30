import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/compliance_data/compliance_data.dart';
import '../../../data/model/compliance_item_model.dart';

class ExpiringComplianceController extends GetxController {
  final ComplianceData _data = Get.find<ComplianceData>();

  StatusRequest status = StatusRequest.none;
  List<ComplianceItem> items = [];

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getExpiring();
    if (response['status'] == StatusRequest.success) {
      final payload = _unwrap(response['data']);
      final raw = payload?['items'];
      if (raw is List) {
        items = raw
            .map((e) =>
                ComplianceItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
          // Most urgent first (already-expired, then soonest to expire).
          ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Map<String, dynamic>? _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final inner = body['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return body;
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }
}
