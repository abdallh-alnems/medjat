import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/dashboard_data/dashboard_data.dart';
import '../../../data/model/dashboard_model.dart';

class DashboardController extends GetxController {
  final DashboardData _dashboardData = Get.find<DashboardData>();

  StatusRequest status = StatusRequest.none;
  DashboardModel? dashboard;
  int? selectedBranchId;

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    status = StatusRequest.loading;
    update();

    final response = selectedBranchId != null
        ? await _dashboardData.getDashboardByBranch(selectedBranchId!)
        : await _dashboardData.getDashboard();

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data != null) {
        dashboard = DashboardModel.fromJson(
          data is Map<String, dynamic> ? data : {},
        );
      }
      status = StatusRequest.success;
    } else {
      status = response['status'] ?? StatusRequest.failure;
    }
    update();
  }

  void selectBranch(int? branchId) {
    selectedBranchId = branchId;
    loadDashboard();
  }
}
