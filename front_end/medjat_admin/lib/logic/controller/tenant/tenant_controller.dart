import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/tenant_data/tenant_data.dart';
import '../../../data/model/tenant_model.dart';

class TenantController extends GetxController {
  final TenantData _tenantData = Get.find<TenantData>();

  final status = StatusRequest.none.obs;
  final tenants = <TenantModel>[].obs;
  final totalPages = 1.obs;
  final currentPage = 1.obs;
  final searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadTenants();
  }

  Future<void> loadTenants({int? page}) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _tenantData.list(page: page ?? currentPage.value);

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        final items = (data['items'] as List<dynamic>?)
                ?.map((e) => TenantModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        tenants.value = items;
        currentPage.value = data['page'] as int? ?? 1;
      }
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> activateTenant(int id) async {
    final response = await _tenantData.activate(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم تفعيل الشركة', snackPosition: SnackPosition.BOTTOM);
      loadTenants();
    } else {
      _showError(response);
    }
  }

  Future<void> deactivateTenant(int id) async {
    final response = await _tenantData.deactivate(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم إيقاف الشركة', snackPosition: SnackPosition.BOTTOM);
      loadTenants();
    } else {
      _showError(response);
    }
  }

  Future<void> createTenant(TenantModel tenant) async {
    final response = await _tenantData.create(tenant);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم إنشاء الشركة بنجاح', snackPosition: SnackPosition.BOTTOM);
      loadTenants();
    } else {
      _showError(response);
    }
  }

  void _showError(Map<String, dynamic> response) {
    final message = response['message'] as String? ?? 'حدث خطأ';
    Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
  }
}
