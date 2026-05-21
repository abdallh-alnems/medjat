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
    return await _crud.putData(AppLinks.companySettings, data);
  }

  Future<Map<String, dynamic>> updateAttendanceConfig({
    required List<String> methods,
    List<int>? manualAdminIds,
    bool? allowOfflineAttendance,
  }) async {
    final data = <String, dynamic>{
      'attendance_methods': methods,
      'manual_attendance_admin_ids': manualAdminIds,
    };
    if (allowOfflineAttendance != null) {
      data['allow_offline_attendance'] = allowOfflineAttendance;
    }
    return await _crud.putData(AppLinks.companySettings, data);
  }

  // ── Leave settings ─────────────────────────────────────
  Future<Map<String, dynamic>> getLeaveSettings() async {
    return await _crud.getData(AppLinks.leaveSettings);
  }

  /// [carryoverMaxDays] = null means "no carryover" (remaining is dropped).
  Future<Map<String, dynamic>> updateLeaveSettings({
    required int defaultAnnualLeaveDays,
    required int? carryoverMaxDays,
  }) async {
    return await _crud.postData(AppLinks.leaveSettings, {
      'default_annual_leave_days': defaultAnnualLeaveDays,
      'leave_carryover_max_days': carryoverMaxDays,
    });
  }

  /// Carries remaining annual balances from [fromYear] into the next year.
  Future<Map<String, dynamic>> runLeaveRollover(int fromYear) async {
    return await _crud.postData(AppLinks.leaveRollover, {
      'from_year': fromYear,
    });
  }
}
