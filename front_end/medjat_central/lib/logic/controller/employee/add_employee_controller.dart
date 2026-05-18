import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/model/branch_model.dart';

class AddEmployeeController extends GetxController {
  final EmployeeData _employeeData = Get.find<EmployeeData>();
  final BranchData _branchData = Get.find<BranchData>();

  final status = StatusRequest.none.obs;
  List<BranchModel> branches = [];

  String? activationCode;
  int? createdEmployeeId;
  int? selectedBranchId;

  @override
  void onInit() {
    super.onInit();
    loadBranches();
  }

  Future<void> loadBranches() async {
    final response = await _branchData.getBranches();
    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is List) {
        branches =
            data.map((e) => BranchModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      update();
    }
  }

  Future<void> createEmployee(Map<String, dynamic> data) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _employeeData.createEmployee(data);

    if (response['status'] == StatusRequest.success) {
      final responseData = response['data'];
      if (responseData is Map<String, dynamic>) {
        createdEmployeeId = (responseData['employee']
            as Map<String, dynamic>?)?['id'] as int?;
        activationCode = responseData['activation_code'] as String?;
      }

      if (activationCode != null) {
        status.value = StatusRequest.success;
      } else if (createdEmployeeId != null) {
        await _generateActivationCode(createdEmployeeId!);
      } else {
        status.value = StatusRequest.success;
      }

      Get.snackbar(
        'تم',
        'تم إضافة الموظف بنجاح',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      status.value = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
      final message = (response['message'] as String?) ?? 'حدث خطأ، حاول مرة أخرى';
      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> _generateActivationCode(int employeeId) async {
    final response = await _employeeData.getEmployee(employeeId);
    if (response['status'] == StatusRequest.success) {
      final respData = response['data'];
      if (respData is Map<String, dynamic>) {
        activationCode = respData['activation_code'] as String?;
      }
    }
  }
}
