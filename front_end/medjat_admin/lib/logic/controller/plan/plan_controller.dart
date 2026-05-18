import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/plan_data/plan_data.dart';
import '../../../data/model/plan_model.dart';

class PlanController extends GetxController {
  final PlanData _planData = Get.find<PlanData>();

  final status = StatusRequest.none.obs;
  final plans = <PlanModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadPlans();
  }

  Future<void> loadPlans() async {
    status.value = StatusRequest.loading;
    update();

    final response = await _planData.list();

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        final items = (data['plans'] as List<dynamic>?)
                ?.map((e) => PlanModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        plans.value = items;
      }
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> createPlan({
    required String name,
    double price = 0,
    int maxEmployees = 10,
    int maxBranches = 1,
  }) async {
    final response = await _planData.create(
      name: name,
      price: price,
      maxEmployees: maxEmployees,
      maxBranches: maxBranches,
    );
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم إنشاء الباقة', snackPosition: SnackPosition.BOTTOM);
      loadPlans();
    } else {
      final message = response['message'] as String? ?? 'حدث خطأ';
      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> updatePlan({
    required int id,
    String? name,
    double? price,
    int? maxEmployees,
    int? maxBranches,
  }) async {
    final response = await _planData.update(
      id: id,
      name: name,
      price: price,
      maxEmployees: maxEmployees,
      maxBranches: maxBranches,
    );
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم تحديث الباقة', snackPosition: SnackPosition.BOTTOM);
      loadPlans();
    } else {
      final message = response['message'] as String? ?? 'حدث خطأ';
      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
  }
}
