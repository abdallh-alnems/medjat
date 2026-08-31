import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/manager_data/manager_data.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/manager_invitation_model.dart';
import '../auth/auth_controller.dart';

class TeamController extends GetxController {
  final ManagerData _data = Get.find<ManagerData>();
  final BranchData _branchData = Get.find<BranchData>();

  // Permission catalog — mirrors RoleModel::getAvailablePermissions() (backend).
  static const List<String> allPermissionKeys = [
    'manage_employees',
    'manage_deduction_rules',
    'manage_attendance',
    'view_reports',
    'manage_documents',
    'documents_manage_types',
    'documents_verify',
    'documents_view_reports',
    'manage_payroll',
    'manage_leaves',
    'manage_assets',
    'add_managers',
    'manage_company_settings',
    'manage_support',
  ];

  // Role defaults — mirrors RoleModel::getRoleDefaults() (backend).
  static const Map<String, List<String>> roleDefaultsByRole = {
    'hr': [
      'manage_employees',
      'manage_deduction_rules',
      'manage_attendance',
      'view_reports',
      'manage_documents',
      'manage_payroll',
      'manage_leaves',
      'manage_assets',
    ],
    'branch_manager': [
      'manage_employees',
      'manage_attendance',
      'manage_documents',
      'view_reports',
      'manage_assets',
    ],
    'attendance': ['manage_attendance'],
    'viewer': ['view_reports'],
  };

  StatusRequest status = StatusRequest.none;
  List<AdminModel> admins = [];
  List<ManagerInvitationModel> invitations = [];
  List<BranchModel> branches = [];

  // ── Filtering / search ──
  String adminSearch = '';
  String invitationFilter = 'pending'; // pending | accepted | expired | cancelled | all

  StatusRequest permissionsStatus = StatusRequest.none;
  final Map<int, List<String>> _effectivePermissionsCache = {};
  List<String> allPermissions = const [];
  List<String> roleDefaults = const [];
  List<String> selectedPermissions = const [];
  bool isCustomized = false;

  int get currentAdminId => Get.find<AuthController>().user?.id ?? 0;
  bool get isGeneralManager =>
      Get.find<AuthController>().user?.isGeneralManager ?? false;

  List<AdminModel> get filteredAdmins {
    final q = adminSearch.trim().toLowerCase();
    if (q.isEmpty) return admins;
    return admins
        .where((a) =>
            a.name.toLowerCase().contains(q) ||
            a.email.toLowerCase().contains(q) ||
            (a.branchName?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<ManagerInvitationModel> get filteredInvitations {
    if (invitationFilter == 'all') return invitations;
    return invitations
        .where((i) => i.statusKey == invitationFilter)
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    status = StatusRequest.loading;
    update();
    await Future.wait([loadAdmins(), loadInvitations(), loadBranches()]);
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

  Future<void> loadBranches() async {
    final response = await _branchData.getBranches();
    if (response['status'] == StatusRequest.success) {
      branches = _extractList(response['data'])
          .whereType<Map<String, dynamic>>()
          .map(BranchModel.fromJson)
          .toList();
    }
  }

  void setAdminSearch(String value) {
    adminSearch = value;
    update();
  }

  void setInvitationFilter(String value) {
    invitationFilter = value;
    update();
  }

  Future<String?> createInvitation({
    required String email,
    required String role,
    String? name,
    int? branchId,
    List<String>? permissions,
  }) async {
    final response = await _data.createInvitation({
      'email': email,
      'role': role,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'branch_id': ?branchId,
      'permissions': ?permissions,
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
    Get.snackbar('error'.tr,
        (response['message'] as String?) ?? 'invitation_create_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return null;
  }

  Future<bool> cancelInvitation(int id) async {
    final response = await _data.cancelInvitation(id);
    if (response['status'] == StatusRequest.success) {
      await loadInvitations();
      update();
      Get.snackbar('done'.tr, 'invitation_cancelled'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return true;
    }
    return false;
  }

  Future<String?> resendInvitation(int id) async {
    final response = await _data.resendInvitation(id);
    if (response['status'] == StatusRequest.success) {
      String? code;
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is Map) code = payload['invitation_code'] as String?;
      await loadInvitations();
      update();
      return code;
    }
    Get.snackbar('error'.tr,
        (response['message'] as String?) ?? 'invitation_resend_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return null;
  }

  Future<bool> updateAdmin({
    required int adminId,
    String? role,
    int? branchId,
    bool branchProvided = false,
  }) async {
    final response = await _data.updateAdmin(
      adminId: adminId,
      role: role,
      branchId: branchId,
      branchProvided: branchProvided,
    );
    if (response['status'] == StatusRequest.success) {
      await loadAdmins();
      update();
      Get.snackbar('done'.tr, 'admin_updated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return true;
    }
    Get.snackbar('error'.tr,
        (response['message'] as String?) ?? 'admin_update_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  Future<bool> setAdminActive(int adminId, bool isActive) async {
    final response =
        await _data.setAdminActive(adminId: adminId, isActive: isActive);
    if (response['status'] == StatusRequest.success) {
      await loadAdmins();
      update();
      Get.snackbar('done'.tr,
          isActive ? 'admin_activated'.tr : 'admin_deactivated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return true;
    }
    Get.snackbar('error'.tr,
        (response['message'] as String?) ?? 'admin_update_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  Future<bool> removeAdmin(int adminId) async {
    final response = await _data.removeAdmin(adminId);
    if (response['status'] == StatusRequest.success) {
      _effectivePermissionsCache.remove(adminId);
      await loadAdmins();
      update();
      Get.snackbar('done'.tr, 'admin_removed'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return true;
    }
    Get.snackbar('error'.tr,
        (response['message'] as String?) ?? 'admin_remove_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
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

      final effective = (payload['effective_permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final defaults = (payload['role_defaults'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final all = (payload['all_permissions'] as List<dynamic>?)
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
    Get.snackbar('error'.tr,
        (response['message'] as String?) ?? 'permissions_save_failed'.tr,
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
    Get.snackbar('error'.tr,
        (response['message'] as String?) ?? 'permissions_reset_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  List<dynamic> _extractList(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    if (payload is List) return payload;
    if (payload is Map) {
      for (final key in const ['items', 'records', 'list', 'branches', 'data']) {
        if (payload[key] is List) return payload[key] as List;
      }
    }
    return const [];
  }
}
