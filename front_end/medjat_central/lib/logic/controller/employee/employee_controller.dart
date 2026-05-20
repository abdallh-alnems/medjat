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
      employees = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  List<EmployeeModel> _extractItems(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) {
      payload = payload['data'];
    }
    List<dynamic>? items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      for (final key in const ['items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          items = payload[key] as List;
          break;
        }
      }
    }
    if (items == null) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(EmployeeModel.fromJson)
        .toList();
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
