import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/company_settings_data/company_settings_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/manager_data/manager_data.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/manager_invitation_model.dart';
import '../../../data/model/attendance_override_model.dart';

class AttendanceMethodController extends GetxController {
  final CompanySettingsData _companySettingsData =
      Get.find<CompanySettingsData>();
  final BranchData _branchData = Get.find<BranchData>();
  final ManagerData _managerData = Get.find<ManagerData>();

  StatusRequest status = StatusRequest.none;
  Set<String> tenantMethods = {'qr_gps', 'manual'};
  List<int>? manualAdminIds;
  bool allowOffline = true;
  double? companyLat;
  double? companyLng;
  int companyRadius = 100;
  List<BranchModel> branches = [];
  List<AdminModel> eligibleAdmins = [];

  bool get hasCompanyLocation => companyLat != null && companyLng != null;
  List<CategoryMethodOverride> categories = [];
  List<EmployeeMethodOverride> employeeOverrides = [];

  static const allMethods = ['qr_gps', 'gps_only', 'manual', 'station'];

  int get branchOverrideCount =>
      branches.where((b) => b.attendanceMethods != null).length;
  int get categoryOverrideCount =>
      categories.where((c) => c.hasOverride).length;
  int get employeeOverrideCount => employeeOverrides.length;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final response = await _companySettingsData.getCompanySettings();

    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map) {
        if (data['attendance_methods'] is List) {
          // Keep only known methods — legacy/invalid values (e.g. "offline")
          // would otherwise be re-sent on save and rejected by the backend.
          tenantMethods = (data['attendance_methods'] as List)
              .map((e) => e.toString())
              .where(allMethods.contains)
              .toSet();
          if (tenantMethods.isEmpty) tenantMethods = {'qr_gps'};
        }
        if (data['manual_attendance_admin_ids'] is List) {
          manualAdminIds = (data['manual_attendance_admin_ids'] as List)
              .map((e) => (e is int) ? e : int.parse(e.toString()))
              .toList();
        } else {
          manualAdminIds = null;
        }
        if (data['allow_offline_attendance'] is bool) {
          allowOffline = data['allow_offline_attendance'] as bool;
        } else {
          allowOffline = true;
        }
        companyLat = (data['gps_latitude'] as num?)?.toDouble();
        companyLng = (data['gps_longitude'] as num?)?.toDouble();
        companyRadius = (data['gps_radius_meters'] as num?)?.toInt() ?? 100;
        if (data['branches'] is List) {
          branches = (data['branches'] as List)
              .map(
                  (e) => BranchModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        if (data['categories'] is List) {
          categories = (data['categories'] as List)
              .map((e) =>
                  CategoryMethodOverride.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        if (data['employee_overrides'] is List) {
          employeeOverrides = (data['employee_overrides'] as List)
              .map((e) =>
                  EmployeeMethodOverride.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      status = StatusRequest.success;
    } else {
      status =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<bool> toggleTenantMethod(String method, bool enabled) async {
    if (enabled) {
      tenantMethods.add(method);
    } else {
      if (tenantMethods.length <= 1) return false;
      tenantMethods.remove(method);
      if (method == 'manual') {
        manualAdminIds = null;
      }
    }

    final response = await _companySettingsData.updateAttendanceConfig(
      methods: tenantMethods.toList(),
      manualAdminIds: manualAdminIds,
      allowOfflineAttendance: allowOffline,
    );
    if (response['status'] == StatusRequest.success) {
      update();
      return true;
    }
    if (!enabled) {
      tenantMethods.add(method);
    } else {
      tenantMethods.remove(method);
    }
    update();
    return false;
  }

  Future<bool> toggleAllowOffline(bool enabled) async {
    final previous = allowOffline;
    allowOffline = enabled;

    final response = await _companySettingsData.updateAttendanceConfig(
      methods: tenantMethods.toList(),
      manualAdminIds: manualAdminIds,
      allowOfflineAttendance: enabled,
    );
    if (response['status'] == StatusRequest.success) {
      update();
      return true;
    }
    allowOffline = previous;
    update();
    return false;
  }

  Future<bool> saveManualAdminIds(List<int>? ids) async {
    final previousIds = manualAdminIds;
    manualAdminIds = ids;

    final response = await _companySettingsData.updateAttendanceConfig(
      methods: tenantMethods.toList(),
      manualAdminIds: ids,
      allowOfflineAttendance: allowOffline,
    );
    if (response['status'] == StatusRequest.success) {
      update();
      return true;
    }
    manualAdminIds = previousIds;
    return false;
  }

  Future<bool> saveBranchMethods({
    required int branchId,
    List<String>? methods,
    int? radius,
    bool? allowOfflineAttendance,
  }) async {
    final response = await _branchData.updateBranchAttendanceMethods(
      branchId: branchId,
      methods: methods,
      gpsRadiusMeters: radius,
      allowOfflineAttendance: allowOfflineAttendance,
    );
    if (response['status'] == StatusRequest.success) {
      final idx = branches.indexWhere((b) => b.id == branchId);
      if (idx != -1) {
        branches[idx] = branches[idx].copyWith(
          attendanceMethods: methods,
          gpsRadiusMeters: radius ?? branches[idx].gpsRadiusMeters,
          allowOfflineAttendance: allowOfflineAttendance,
        );
      }
      update();
      return true;
    }
    return false;
  }

  /// Set (methods != null) or clear (methods == null = inherit) a category override.
  Future<bool> saveCategoryMethods(int categoryId, List<String>? methods) async {
    final response = await _companySettingsData.setMethodOverride(
      scopeType: 'category',
      scopeId: categoryId,
      methods: methods,
    );
    if (response['status'] == StatusRequest.success) {
      final idx = categories.indexWhere((c) => c.id == categoryId);
      if (idx != -1) categories[idx].methods = methods;
      update();
      return true;
    }
    return false;
  }

  /// Set or clear (methods == null) an employee override. [name]/[branchName]
  /// are used to add a new row to the list when an override is first set.
  Future<bool> saveEmployeeMethods(
    int employeeId,
    List<String>? methods, {
    String? name,
    String? branchName,
  }) async {
    final response = await _companySettingsData.setMethodOverride(
      scopeType: 'employee',
      scopeId: employeeId,
      methods: methods,
    );
    if (response['status'] == StatusRequest.success) {
      final idx = employeeOverrides.indexWhere((e) => e.id == employeeId);
      if (methods == null) {
        if (idx != -1) employeeOverrides.removeAt(idx);
      } else if (idx != -1) {
        employeeOverrides[idx].methods = methods;
      } else {
        employeeOverrides.add(EmployeeMethodOverride(
          id: employeeId,
          name: name ?? '',
          branchName: branchName,
          methods: methods,
        ));
      }
      update();
      return true;
    }
    return false;
  }

  /// Persist the company-wide GPS geofence (used by the location sheet).
  Future<Map<String, dynamic>> persistCompanyLocation(
      double lat, double lng, int radius) {
    return _companySettingsData.setCompanyLocation(
        lat: lat, lng: lng, radius: radius);
  }

  /// Reflect a saved company-wide GPS geofence locally.
  void applyCompanyLocation(double lat, double lng, int radius) {
    companyLat = lat;
    companyLng = lng;
    companyRadius = radius;
    update();
  }

  /// Reflect a saved GPS geofence (center + radius) in the local branch list.
  void applyBranchLocation(int branchId, double lat, double lng, int radius) {
    final idx = branches.indexWhere((b) => b.id == branchId);
    if (idx != -1) {
      branches[idx] = branches[idx].copyWith(
        lat: lat,
        lng: lng,
        gpsRadiusMeters: radius,
      );
      update();
    }
  }

  Future<void> loadEligibleAdmins() async {
    final response = await _managerData.getAdmins();
    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is Map<String, dynamic> && data['items'] is List) {
        eligibleAdmins = (data['items'] as List)
            .map((e) => AdminModel.fromJson(e as Map<String, dynamic>))
            .where((a) => a.isActive)
            .toList();
      }
      update();
    }
  }
}
