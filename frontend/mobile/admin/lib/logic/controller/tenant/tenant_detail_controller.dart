import 'dart:async';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/tenant_data/tenant_data.dart';
import '../../../data/model/tenant_detail_model.dart';
import '../../../data/model/tenant_diagnostics_model.dart';

/// One company's profile, its diagnostics, and the actions we can take on it.
///
/// Diagnostics load separately and lazily: the profile is what you always want,
/// the diagnostics are what you want when something is wrong, and they are the
/// heavier query of the two.
class TenantDetailController extends GetxController {
  final TenantData _tenantData = Get.find<TenantData>();

  final int tenantId;
  TenantDetailController(this.tenantId);

  final status = StatusRequest.none.obs;
  final detail = Rxn<TenantDetailModel>();

  final diagnosticsStatus = StatusRequest.none.obs;
  final diagnostics = Rxn<TenantDiagnosticsModel>();
  final diagnosticsLoaded = false.obs;

  final busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadDetail();
  }

  Future<void> loadDetail() async {
    status.value = StatusRequest.loading;
    update();

    final response = await _tenantData.detail(tenantId);
    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        detail.value = TenantDetailModel.fromJson(data as Map<String, dynamic>);
      }
      status.value = StatusRequest.success;
    } else {
      status.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> loadDiagnostics({bool force = false}) async {
    if (diagnosticsLoaded.value && !force) return;

    diagnosticsStatus.value = StatusRequest.loading;
    update();

    final response = await _tenantData.diagnostics(tenantId);
    if (response['status'] == StatusRequest.success) {
      final data = response['data']?['data'] ?? response['data'];
      if (data != null) {
        diagnostics.value = TenantDiagnosticsModel.fromJson(data as Map<String, dynamic>);
      }
      diagnosticsStatus.value = StatusRequest.success;
      diagnosticsLoaded.value = true;
    } else {
      diagnosticsStatus.value = response['status'] as StatusRequest? ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> refreshAll() async {
    await loadDetail();
    if (diagnosticsLoaded.value) {
      await loadDiagnostics(force: true);
    }
  }

  Future<bool> saveContact({
    String? name,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? opsNotes,
  }) async {
    final fields = <String, dynamic>{};
    if (name != null) fields['name'] = name;
    if (contactName != null) fields['contact_name'] = contactName;
    if (contactPhone != null) fields['contact_phone'] = contactPhone;
    if (contactEmail != null) fields['contact_email'] = contactEmail;
    if (opsNotes != null) fields['ops_notes'] = opsNotes;
    if (fields.isEmpty) return false;

    busy.value = true;
    update();
    final response = await _tenantData.update(tenantId, fields);
    busy.value = false;

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', 'تم حفظ البيانات', snackPosition: SnackPosition.BOTTOM);
      await loadDetail();
      return true;
    }
    _showError(response);
    update();
    return false;
  }

  Future<void> toggleActive() async {
    final current = detail.value?.tenant.isActiveTenant ?? true;
    busy.value = true;
    update();

    final response = current
        ? await _tenantData.deactivate(tenantId)
        : await _tenantData.activate(tenantId);
    busy.value = false;

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('تم', current ? 'تم إيقاف الشركة' : 'تم تفعيل الشركة',
          snackPosition: SnackPosition.BOTTOM);
      await loadDetail();
    } else {
      _showError(response);
      update();
    }
  }

  /// Invites a manager into this company — the rescue path for a client whose
  /// last general manager is gone. Returns the invitation payload (code, link).
  Future<Map<String, dynamic>?> inviteManager({
    required String email,
    String? name,
    String role = 'general_manager',
  }) async {
    busy.value = true;
    update();

    final response = await _tenantData.inviteManager(
      tenantId: tenantId,
      email: email,
      name: name,
      role: role,
    );
    busy.value = false;

    if (response['status'] == StatusRequest.success) {
      await loadDetail();
      return (response['data']?['data'] ?? response['data']) as Map<String, dynamic>?;
    }
    _showError(response);
    update();
    return null;
  }

  void _showError(Map<String, dynamic> response) {
    final message = response['message'] as String? ?? 'حدث خطأ';
    Get.snackbar('خطأ', message, snackPosition: SnackPosition.BOTTOM);
  }
}
