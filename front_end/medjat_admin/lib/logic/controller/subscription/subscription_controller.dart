import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/subscription_data/subscription_data.dart';
import '../../../data/model/subscription_model.dart';

class SubscriptionController extends GetxController {
  final SubscriptionData _subscriptionData = Get.find<SubscriptionData>();

  final status = StatusRequest.none.obs;
  final subscriptions = <SubscriptionModel>[].obs;
  final currentPage = 1.obs;

  @override
  void onInit() {
    super.onInit();
    loadSubscriptions();
  }

  Future<void> loadSubscriptions({int? page}) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _subscriptionData.list(page: page ?? currentPage.value);

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        final items = (data['items'] as List<dynamic>?)
                ?.map((e) => SubscriptionModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        subscriptions.value = items;
        currentPage.value = data['page'] as int? ?? 1;
      }
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> updateSubscription({
    required int tenantId,
    String? status,
    int? planId,
    String? startDate,
    String? endDate,
  }) async {
    final response = await _subscriptionData.update(
      tenantId: tenantId,
      status: status,
      planId: planId,
      startDate: startDate,
      endDate: endDate,
    );
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم تحديث الاشتراك', snackPosition: SnackPosition.BOTTOM);
      loadSubscriptions();
    } else {
      final message = response['message'] as String? ?? 'حدث خطأ';
      Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
    }
  }
}
