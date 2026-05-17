import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/employee_model.dart';

class EmployeeController extends GetxController {
  final EmployeeData _employeeData = Get.find<EmployeeData>();

  StatusRequest status = StatusRequest.none;
  List<EmployeeModel> employees = [];
  String searchQuery = '';
  int? branchFilter;

  @override
  void onInit() {
    super.onInit();
    loadEmployees();
  }

  Future<void> loadEmployees() async {
    status = StatusRequest.loading;
    update();

    final response = await _employeeData.getEmployees(
      branchId: branchFilter,
      search: searchQuery.isNotEmpty ? searchQuery : null,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is List) {
        employees = data.map((e) => EmployeeModel.fromJson(e)).toList();
      }
      status = StatusRequest.success;
    } else {
      status = response['status'] ?? StatusRequest.failure;
    }
    update();
  }

  void onSearch(String query) {
    searchQuery = query;
    loadEmployees();
  }

  void filterByBranch(int? branchId) {
    branchFilter = branchId;
    loadEmployees();
  }
}
