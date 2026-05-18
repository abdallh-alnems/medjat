import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/notification_data/notification_data.dart';

class NotificationController extends GetxController {
  final NotificationData _notificationData = Get.find<NotificationData>();

  final status = StatusRequest.none.obs;
  final isTenantSpecific = false.obs;
  final selectedTenantId = 0.obs;

  Future<void> sendNotification({
    required String title,
    required String body,
  }) async {
    status.value = StatusRequest.loading;
    update();

    Map<String, dynamic> response;

    if (isTenantSpecific.value && selectedTenantId.value > 0) {
      response = await _notificationData.sendToTenant(
        tenantId: selectedTenantId.value,
        title: title,
        body: body,
      );
    } else {
      response = await _notificationData.sendAll(title: title, body: body);
    }

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم إرسال الإشعار', snackPosition: SnackPosition.BOTTOM);
    } else {
      final msg = response['message'] as String? ?? 'حدث خطأ';
      Get.snackbar('خطأ', msg, snackPosition: SnackPosition.BOTTOM);
    }
    status.value = StatusRequest.none;
    update();
  }
}
