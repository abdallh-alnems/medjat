import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/notification_data/notification_data.dart';
import '../../../data/data_source/remote/tenant_data/tenant_data.dart';
import '../../../data/model/tenant_model.dart';

/// Composing an announcement.
///
/// Two things the old screen got wrong: the company was typed in as a raw id,
/// and "send to everyone" only ever reached company managers. Both are now
/// explicit — pick the company from a list, pick who should receive it.
class NotificationController extends GetxController {
  final NotificationData _notificationData = Get.find<NotificationData>();
  final TenantData _tenantData = Get.find<TenantData>();

  final status = StatusRequest.none.obs;
  final isTenantSpecific = false.obs;
  final selectedTenantId = 0.obs;
  final selectedTenantName = ''.obs;

  /// `admins` | `employees` | `all`
  final audience = 'admins'.obs;

  final tenants = <TenantModel>[].obs;
  final tenantsLoading = false.obs;

  /// Result of the last send, so the screen can report exactly who was reached.
  final lastResult = Rxn<Map<String, dynamic>>();

  static const Map<String, String> audienceLabels = {
    'admins': 'مديرو الشركات',
    'employees': 'الموظفون',
    'all': 'الجميع',
  };

  Future<void> loadTenants() async {
    if (tenants.isNotEmpty || tenantsLoading.value) return;
    tenantsLoading.value = true;
    update();

    final response = await _tenantData.list(limit: 100);
    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      tenants.value = (data?['items'] as List<dynamic>? ?? const [])
          .map((e) => TenantModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    tenantsLoading.value = false;
    update();
  }

  void selectTenant(TenantModel tenant) {
    selectedTenantId.value = tenant.id;
    selectedTenantName.value = tenant.name;
    update();
  }

  void setAudience(String value) {
    audience.value = value;
    update();
  }

  Future<bool> sendNotification({
    required String title,
    required String body,
  }) async {
    if (isTenantSpecific.value && selectedTenantId.value <= 0) {
      Get.snackbar('خطأ', 'اختر الشركة أولًا', snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    status.value = StatusRequest.loading;
    update();

    final response = isTenantSpecific.value
        ? await _notificationData.sendToTenant(
            tenantId: selectedTenantId.value,
            title: title,
            body: body,
            audience: audience.value,
          )
        : await _notificationData.sendAll(
            title: title,
            body: body,
            audience: audience.value,
          );

    status.value = StatusRequest.none;

    if (response['status'] == StatusRequest.success) {
      final data = (response['data']?['data'] ?? response['data']) as Map<String, dynamic>?;
      lastResult.value = data;

      final sentAdmins = data?['sent_admins'] as int? ?? 0;
      final sentEmployees = data?['sent_employees'] as int? ?? 0;
      final parts = <String>[
        if (sentAdmins > 0) '$sentAdmins مدير',
        if (sentEmployees > 0) '$sentEmployees موظف',
      ];
      Get.snackbar(
        'تم الإرسال',
        parts.isEmpty ? 'لا توجد أجهزة مسجّلة لاستقبال الإشعار' : 'وصل إلى ${parts.join(' و ')}',
        snackPosition: SnackPosition.BOTTOM,
      );
      update();
      return true;
    }

    final msg = response['message'] as String? ?? 'حدث خطأ';
    Get.snackbar('خطأ', msg, snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }
}
