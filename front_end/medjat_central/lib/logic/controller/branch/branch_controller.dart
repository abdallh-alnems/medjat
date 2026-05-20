import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/model/branch_model.dart';

class BranchController extends GetxController {
  final BranchData _branchData = Get.find<BranchData>();

  StatusRequest status = StatusRequest.none;
  List<BranchModel> branches = [];

  @override
  void onInit() {
    super.onInit();
    loadBranches();
  }

  Future<void> loadBranches() async {
    status = StatusRequest.loading;
    update();

    final response = await _branchData.getBranches();

    if (response['status'] == StatusRequest.success) {
      var data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map && data['branches'] != null) {
        branches = (data['branches'] as List)
            .map((e) => BranchModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (data is List) {
        branches =
            data.map((e) => BranchModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }
}
