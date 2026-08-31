import 'dart:async';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/tenant_data/tenant_data.dart';
import '../../../data/model/tenant_model.dart';

/// The client list: searchable, paginated, and the entry point to onboarding.
class TenantController extends GetxController {
  final TenantData _tenantData = Get.find<TenantData>();

  final status = StatusRequest.none.obs;
  final tenants = <TenantModel>[].obs;
  final totalPages = 1.obs;
  final total = 0.obs;
  final currentPage = 1.obs;
  final searchQuery = ''.obs;
  final statusFilter = ''.obs;

  /// Set after a successful onboarding so the screen can show the invitation
  /// code once — it is never retrievable again.
  final lastInvitation = Rxn<Map<String, dynamic>>();

  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    loadTenants();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  Future<void> loadTenants({int? page}) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _tenantData.list(
      page: page ?? currentPage.value,
      q: searchQuery.value,
      status: statusFilter.value,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        tenants.value = (data['items'] as List<dynamic>?)
                ?.map((e) => TenantModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        currentPage.value = data['page'] as int? ?? 1;
        totalPages.value = data['total_pages'] as int? ?? 1;
        total.value = data['total'] as int? ?? tenants.length;
      }
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }

  /// Typing shouldn't fire a request per keystroke.
  void onSearchChanged(String value) {
    searchQuery.value = value;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      currentPage.value = 1;
      loadTenants(page: 1);
    });
  }

  void setStatusFilter(String value) {
    statusFilter.value = value;
    currentPage.value = 1;
    loadTenants(page: 1);
  }

  bool get hasNextPage => currentPage.value < totalPages.value;
  bool get hasPreviousPage => currentPage.value > 1;

  void nextPage() {
    if (hasNextPage) loadTenants(page: currentPage.value + 1);
  }

  void previousPage() {
    if (hasPreviousPage) loadTenants(page: currentPage.value - 1);
  }

  Future<void> activateTenant(int id) async {
    final response = await _tenantData.activate(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم تفعيل الشركة', snackPosition: SnackPosition.BOTTOM);
      unawaited(loadTenants());
    } else {
      _showError(response);
    }
  }

  Future<void> deactivateTenant(int id) async {
    final response = await _tenantData.deactivate(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم إيقاف الشركة', snackPosition: SnackPosition.BOTTOM);
      unawaited(loadTenants());
    } else {
      _showError(response);
    }
  }

  /// Creates the company and, when an owner email is supplied, the pending
  /// general_manager invitation that lets anyone log into it at all.
  ///
  /// Returns true on success; the invitation (if any) is left in
  /// [lastInvitation] for the screen to display.
  Future<bool> createTenant({
    required String name,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? opsNotes,
    String? ownerEmail,
    String? ownerName,
    String? timezone,
    String? currency,
  }) async {
    status.value = StatusRequest.loading;
    update();

    final response = await _tenantData.create(
      name: name,
      contactName: contactName,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      opsNotes: opsNotes,
      ownerEmail: ownerEmail,
      ownerName: ownerName,
      timezone: timezone,
      currency: currency,
    );

    status.value = StatusRequest.none;

    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      lastInvitation.value = data?['invitation'] as Map<String, dynamic>?;
      Get.snackbar('تم', 'تم إنشاء الشركة', snackPosition: SnackPosition.BOTTOM);
      await loadTenants(page: 1);
      return true;
    }

    _showError(response);
    update();
    return false;
  }

  void _showError(Map<String, dynamic> response) {
    final message = response['message'] as String? ?? 'حدث خطأ';
    Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
  }
}
