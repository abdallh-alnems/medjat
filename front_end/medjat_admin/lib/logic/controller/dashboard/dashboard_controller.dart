import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/dashboard_data/dashboard_data.dart';
import '../../../data/model/dashboard_model.dart';

class DashboardController extends GetxController {
  final DashboardData _dashboardData = Get.find<DashboardData>();

  final status = StatusRequest.none.obs;
  DashboardModel? dashboard;

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    status.value = StatusRequest.loading;
    update();

    final response = await _dashboardData.overview();

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        dashboard = DashboardModel.fromJson(data as Map<String, dynamic>);
      }
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }
}
