import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/manager_data/manager_data.dart';
import '../../../data/model/manager_invitation_model.dart';

class TeamController extends GetxController {
  final ManagerData _data = Get.find<ManagerData>();

  StatusRequest status = StatusRequest.none;
  List<AdminModel> admins = [];
  List<ManagerInvitationModel> invitations = [];

  StatusRequest permissionsStatus = StatusRequest.none;
  Map<int, List<String>> _effectivePermissionsCache = {};
  List<String> allPermissions = const [];
  List<String> roleDefaults = const [];
  List<String> selectedPermissions = const [];
  bool isCustomized = false;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    status = StatusRequest.loading;
    update();
    await Future.wait([loadAdmins(), loadInvitations()]);
    status = StatusRequest.success;
    update();
  }

  Future<void> loadAdmins() async {
    final response = await _data.getAdmins();
    if (response['status'] == StatusRequest.success) {
      admins = _extractList(response['data'])
          .whereType<Map<String, dynamic>>()
          .map(AdminModel.fromJson)
          .toList();
    }
  }

  Future<void> loadInvitations() async {
    final response = await _data.getInvitations();
    if (response['status'] == StatusRequest.success) {
      invitations = _extractList(response['data'])
          .whereType<Map<String, dynamic>>()
          .map(ManagerInvitationModel.fromJson)
          .toList();
    }
  }

  Future<String?> createInvitation({
    required String email,
    required String role,
    int? branchId,
  }) async {
    final response = await _data.createInvitation({
      'email': email,
      'role': role,
      if (branchId != null) 'branch_id': branchId,
    });
    if (response['status'] == StatusRequest.success) {
      String? code;
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is Map) code = payload['invitation_code'] as String?;
      await loadInvitations();
      update();
      return code;
    }
    Get.snackbar('خطأ',
        (response['message'] as String?) ?? 'فشل إنشاء الدعوة',
        snackPosition: SnackPosition.BOTTOM);
    return null;
  }

  Future<bool> cancelInvitation(int id) async {
    final response = await _data.cancelInvitation(id);
    if (response['status'] == StatusRequest.success) {
      await loadInvitations();
      update();
      Get.snackbar('تم', 'تم إلغاء الدعوة',
          snackPosition: SnackPosition.BOTTOM);
      return true;
    }
    return false;
  }

  Future<void> loadAdminPermissions(int adminId) async {
    permissionsStatus = StatusRequest.loading;
    update();

    final response = await _data.getAdminPermissions(adminId);
    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is! Map) {
        permissionsStatus = StatusRequest.failure;
        update();
        return;
      }

      final effective = (payload['effective_permissions'] as List<dynamic>)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final defaults = (payload['role_defaults'] as List<dynamic>)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final all = (payload['all_permissions'] as List<dynamic>)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      _effectivePermissionsCache[adminId] = effective;
      roleDefaults = defaults;
      allPermissions = all;
      selectedPermissions = List<String>.from(effective);
      isCustomized = payload['is_customized'] == true;
      permissionsStatus = StatusRequest.success;
    } else {
      permissionsStatus = StatusRequest.failure;
    }
    update();
  }

  void togglePermission(String key) {
    final updated = List<String>.from(selectedPermissions);
    if (updated.contains(key)) {
      updated.remove(key);
    } else {
      updated.add(key);
    }
    selectedPermissions = updated;
    update();
  }

  Future<bool> saveAdminPermissions(int adminId) async {
    final response = await _data.updateAdminPermissions(
      adminId: adminId,
      permissions: selectedPermissions,
    );
    if (response['status'] == StatusRequest.success) {
      _effectivePermissionsCache[adminId] =
          List<String>.from(selectedPermissions);
      isCustomized = true;
      await loadAdmins();
      update();
      return true;
    }
    Get.snackbar('خطأ',
        (response['message'] as String?) ?? 'فشل حفظ الصلاحيات',
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  Future<bool> resetAdminPermissions(int adminId) async {
    final response = await _data.resetAdminPermissions(adminId);
    if (response['status'] == StatusRequest.success) {
      _effectivePermissionsCache.remove(adminId);
      selectedPermissions = List<String>.from(roleDefaults);
      isCustomized = false;
      await loadAdmins();
      update();
      return true;
    }
    Get.snackbar('خطأ',
        (response['message'] as String?) ?? 'فشل إعادة التعيين',
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  List<dynamic> _extractList(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    if (payload is List) return payload;
    if (payload is Map) {
      for (final key in const ['items', 'records', 'list', 'data']) {
        if (payload[key] is List) return payload[key] as List;
      }
    }
    return const [];
  }
}
