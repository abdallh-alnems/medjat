import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/role_data/role_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/model/role_model.dart';
import '../../../data/model/branch_model.dart';

class RoleManagementController extends GetxController {
  final RoleData _roleData = Get.find<RoleData>();
  final BranchData _branchData = Get.find<BranchData>();

  StatusRequest status = StatusRequest.none;
  List<RoleModel> roles = [];
  List<BranchModel> branches = [];

  @override
  void onInit() {
    super.onInit();
    loadRoles();
    loadBranches();
  }

  Future<void> loadRoles() async {
    status = StatusRequest.loading;
    update();

    final response = await _roleData.getRoles();

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is List) {
        roles = data.map((e) => RoleModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
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

  Future<void> createRole(Map<String, dynamic> data) async {
    final response = await _roleData.createRole(data);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم إضافة الدور', snackPosition: SnackPosition.BOTTOM);
      loadRoles();
    } else {
      Get.snackbar(
          'خطأ', (response['message'] as String?) ?? 'حدث خطأ',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> updateRole(int id, Map<String, dynamic> data) async {
    final response = await _roleData.updateRole(id, data);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم تحديث الدور',
          snackPosition: SnackPosition.BOTTOM);
      loadRoles();
    }
  }

  Future<void> deleteRole(int id) async {
    final response = await _roleData.deleteRole(id);
    if (response['status'] == StatusRequest.success) {
      roles.removeWhere((r) => r.id == id);
      Get.snackbar('تم', 'تم حذف الدور', snackPosition: SnackPosition.BOTTOM);
      update();
    }
  }
}
