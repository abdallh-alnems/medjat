import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/company_settings_data/company_settings_data.dart';

class LeaveEncashmentsController extends GetxController {
  final CompanySettingsData _data = Get.find<CompanySettingsData>();

  StatusRequest status = StatusRequest.none;
  List<Map<String, dynamic>> encashments = [];

  /// null = all, otherwise 'pending' | 'paid' | 'cancelled'.
  String? statusFilter;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getEncashments(status: statusFilter);

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) body = body['data'];
      final list = (body is Map ? body['encashments'] : null);
      encashments = list is List
          ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : [];
      status = encashments.isEmpty ? StatusRequest.success : StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void setFilter(String? value) {
    statusFilter = value;
    load();
  }
}
