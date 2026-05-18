import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/force_update_data/force_update_data.dart';

class ForceUpdateController extends GetxController {
  final ForceUpdateData _forceUpdateData = Get.find<ForceUpdateData>();

  final status = StatusRequest.none.obs;
  final platform = 'all'.obs;
  final minVersion = ''.obs;
  final message = ''.obs;

  Future<void> trigger() async {
    if (minVersion.value.isEmpty) {
      Get.snackbar('خطأ', 'يرجى إدخال رقم الإصدار', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    status.value = StatusRequest.loading;
    update();

    final response = await _forceUpdateData.trigger(
      minVersion: minVersion.value,
      platform: platform.value,
      message: message.value.isEmpty ? 'يرجى تحديث التطبيق للمتابعة' : message.value,
    );

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم إرسال التحديث الإجباري', snackPosition: SnackPosition.BOTTOM);
      minVersion.value = '';
      message.value = '';
    } else {
      final msg = response['message'] as String? ?? 'حدث خطأ';
      Get.snackbar('خطأ', msg, snackPosition: SnackPosition.BOTTOM);
    }
    status.value = StatusRequest.none;
    update();
  }
}
