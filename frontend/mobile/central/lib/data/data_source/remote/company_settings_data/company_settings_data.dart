import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class CompanySettingsData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getCompanySettings() async {
    return await _crud.getData(AppLinks.companySettings);
  }

  Future<Map<String, dynamic>> updateCompanySettings(
      Map<String, dynamic> data) async {
    // POST (not PUT): the backend uses POST and PUT is unreliable on the host.
    return await _crud.postData(AppLinks.companySettings, data);
  }

  /// Every argument is optional and only what is passed is sent.
  ///
  /// `methods` used to be required, so all six callers shipped the full method
  /// list on every save — including the five that change something else
  /// entirely. Combined with the client-side filter that builds that list, any
  /// method the app did not recognise was deleted from the company's
  /// configuration by a switch that had nothing to do with it.
  ///
  /// Omitting it is not merely tidier, it reaches a different branch of the
  /// endpoint: v1/settings/company only touches `attendance_methods` when
  /// the key is present, and re-reads the stored list from the database when it
  /// is not. Send only what this particular save is actually changing.
  Future<Map<String, dynamic>> updateAttendanceConfig({
    List<String>? methods,
    List<int>? manualAdminIds,
    bool? allowOfflineAttendance,
    bool? rejectMockLocation,
    bool? requireLocalBiometric,
  }) async {
    final data = <String, dynamic>{};
    if (methods != null) {
      data['attendance_methods'] = methods;
      // Paired with the methods on purpose: the server clears the manual admin
      // list when 'manual' is switched off, and it can only see that if both
      // arrive together.
      data['manual_attendance_admin_ids'] = manualAdminIds;
    }
    if (allowOfflineAttendance != null) {
      data['allow_offline_attendance'] = allowOfflineAttendance;
    }
    if (rejectMockLocation != null) {
      data['reject_mock_location'] = rejectMockLocation;
    }
    if (requireLocalBiometric != null) {
      data['require_local_biometric'] = requireLocalBiometric;
    }
    // POST (not PUT): the backend uses POST and PUT is unreliable on the host.
    return await _crud.postData(AppLinks.companySettings, data);
  }

  /// Who may record manual attendance, on its own.
  ///
  /// Separate from [updateAttendanceConfig] because `null` here is a real value
  /// — it means "no restriction, any admin may" — and an optional Dart argument
  /// cannot tell that apart from "not passed". Sending the key explicitly, null
  /// included, is the only way to express clearing the list without also having
  /// to ship the method list to carry it.
  Future<Map<String, dynamic>> updateManualAdminIds(List<int>? ids) async {
    return await _crud.postData(AppLinks.companySettings, {
      'manual_attendance_admin_ids': ids,
    });
  }

  /// Company-wide face-recognition settings for the `face_selfie` method.
  /// Sent on their own so they never overwrite the method list.
  Future<Map<String, dynamic>> updateFaceSettings({
    double? matchThreshold,
    bool? livenessRequired,
    String? enforceMode,
  }) async {
    final data = <String, dynamic>{};
    if (matchThreshold != null) data['face_match_threshold'] = matchThreshold;
    if (livenessRequired != null) {
      data['face_liveness_required'] = livenessRequired;
    }
    if (enforceMode != null) data['face_enforce_mode'] = enforceMode;
    return await _crud.postData(AppLinks.companySettings, data);
  }

  /// Company switch for browser attendance, plus whether a photo is captured at
  /// each browser punch. The backend audits every change on its own line.
  Future<Map<String, dynamic>> updateWebAttendanceSettings({
    bool? enabled,
    bool? photoRequired,
  }) async {
    final data = <String, dynamic>{};
    if (enabled != null) data['web_attendance_enabled'] = enabled;
    if (photoRequired != null) {
      data['web_attendance_photo_required'] = photoRequired;
    }
    return await _crud.postData(AppLinks.companySettings, data);
  }

  /// Per-category exception. `allowed: null` restores "inherit the company".
  Future<Map<String, dynamic>> updateCategoryWebAccess({
    required int categoryId,
    required bool? allowed,
  }) async {
    return await _crud.postData(AppLinks.categoryWebAccess, {
      'id': categoryId,
      'web_attendance_allowed': allowed,
    });
  }

  /// Set or clear (lat/lng null) the company-wide GPS geofence — the default
  /// center + radius applied to branches that don't set their own.
  Future<Map<String, dynamic>> setCompanyLocation({
    double? lat,
    double? lng,
    int? radius,
  }) async {
    return await _crud.postData(AppLinks.companySettings, {
      'gps_latitude': lat,
      'gps_longitude': lng,
      'gps_radius_meters': radius,
    });
  }

  /// Set or clear (methods = null) the attendance-method override for a
  /// category or a single employee.
  Future<Map<String, dynamic>> setMethodOverride({
    required String scopeType, // 'category' | 'employee'
    required int scopeId,
    List<String>? methods,
  }) async {
    return await _crud.postData(AppLinks.setAttendanceMethodOverride, {
      'scope_type': scopeType,
      'scope_id': scopeId,
      'attendance_methods': methods,
    });
  }

  // ── Statutory payroll settings ─────────────────────────
  Future<Map<String, dynamic>> getStatutoryPayrollSettings() async {
    return await _crud.getData(AppLinks.statutoryPayrollSettings);
  }

  Future<Map<String, dynamic>> updateStatutoryPayrollSettings(
      Map<String, dynamic> data) async {
    // POST (not PUT): the backend uses POST and PUT is unreliable on the host.
    return await _crud.postData(AppLinks.statutoryPayrollSettings, data);
  }

  // ── Leave settings ─────────────────────────────────────
  Future<Map<String, dynamic>> getLeaveSettings() async {
    return await _crud.getData(AppLinks.leaveSettings);
  }

  /// [carryoverMaxDays] = null means "no carryover" (remaining is dropped).
  Future<Map<String, dynamic>> updateLeaveSettings({
    required int defaultAnnualLeaveDays,
    required bool carryoverEnabled,
    required int? carryoverMaxDays,
    int? expiryMonths,
    bool encashExcess = false,
    int? legalMinDays,
    bool autoRolloverEnabled = false,
    bool applyLegalSeniorityEntitlement = true,
  }) async {
    return await _crud.postData(AppLinks.leaveSettings, {
      'default_annual_leave_days': defaultAnnualLeaveDays,
      'carryover_enabled': carryoverEnabled,
      'leave_carryover_max_days': carryoverMaxDays,
      'carryover_expiry_months': expiryMonths,
      'carryover_encash_excess': encashExcess,
      'carryover_legal_min_days': legalMinDays,
      'auto_rollover_enabled': autoRolloverEnabled,
      'apply_legal_seniority_entitlement': applyLegalSeniorityEntitlement,
    });
  }

  /// Carries remaining annual balances from [fromYear] into the next year.
  Future<Map<String, dynamic>> runLeaveRollover(int fromYear) async {
    return await _crud.postData(AppLinks.leaveRollover, {
      'from_year': fromYear,
    });
  }

  // ── Per-scope carryover policies ───────────────────────
  Future<Map<String, dynamic>> getCarryoverPolicies() async {
    return await _crud.getData(AppLinks.leaveCarryoverPolicies);
  }

  Future<Map<String, dynamic>> saveCarryoverPolicy({
    required String scopeType, // 'branch' | 'category' | 'employee'
    required int scopeId,
    int minSeniorityMonths = 0,
    required bool carryoverEnabled,
    int? carryoverMaxDays,
    int? expiryMonths,
    bool encashExcess = false,
    int? legalMinCarryDays,
  }) async {
    return await _crud.postData(AppLinks.leaveCarryoverPolicySave, {
      'scope_type': scopeType,
      'scope_id': scopeId,
      'min_seniority_months': minSeniorityMonths,
      'carryover_enabled': carryoverEnabled,
      'carryover_max_days': carryoverMaxDays,
      'expiry_months': expiryMonths,
      'encash_excess': encashExcess,
      'legal_min_carry_days': legalMinCarryDays,
    });
  }

  Future<Map<String, dynamic>> deleteCarryoverPolicy(int id) async {
    return await _crud.deleteData(AppLinks.leaveCarryoverPolicyDelete(id));
  }

  // ── Leave encashments ──────────────────────────────────
  Future<Map<String, dynamic>> getEncashments({String? status}) async {
    final url = status == null || status.isEmpty
        ? AppLinks.leaveEncashments
        : '${AppLinks.leaveEncashments}?status=$status';
    return await _crud.getData(url);
  }
}
