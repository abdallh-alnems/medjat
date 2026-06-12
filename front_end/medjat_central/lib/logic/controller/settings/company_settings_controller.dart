import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/company_settings_data/company_settings_data.dart';

class CompanySettingsController extends GetxController {
  final CompanySettingsData _companySettingsData =
      Get.find<CompanySettingsData>();

  StatusRequest status = StatusRequest.none;
  Map<String, dynamic> companyData = {};

  final nameController = TextEditingController();

  // Localization preferences (sent to the backend on save).
  String currency = 'EGP';
  String timezone = 'Africa/Cairo';

  // Full list of IANA timezone identifiers offered in the picker, loaded from
  // the device at startup (falls back to a minimal set if unavailable).
  List<String> availableTimezones = const ['UTC', 'Africa/Cairo'];

  // True when [timezone] was auto-filled from the device location rather than
  // an explicit company choice. Cleared once the user picks one manually.
  bool timezoneAutoDetected = false;

  // Company default attendance cycle start day (1-28). Branches may override.
  int cycleStartDay = 1;

  // Weekly-schedule start weekday (ISO: 1=Mon..7=Sun, default 6=Sat).
  int weekStartDay = 6;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    await _loadAvailableTimezones();
    await loadSettings();
  }

  /// Loads the full IANA timezone list from the bundled tz database (pure
  /// Dart, so it does not depend on a native platform call succeeding).
  Future<void> _loadAvailableTimezones() async {
    try {
      tz_data.initializeTimeZones();
      final ids = tz.timeZoneDatabase.locations.keys.toList()..sort();
      if (ids.isNotEmpty) {
        availableTimezones = ids;
      }
    } catch (_) {
      // Keep the minimal fallback list defined above.
    }
    update();
  }

  /// The device's current timezone (driven by the OS region/location setting),
  /// or null if it cannot be resolved.
  Future<String?> _detectDeviceTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return info.identifier.isNotEmpty ? info.identifier : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }

  Future<void> loadSettings() async {
    status = StatusRequest.loading;
    update();

    final response = await _companySettingsData.getCompanySettings();

    if (response['status'] == StatusRequest.success) {
      // Unwrap the API envelope: {status, data:{...}}.
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map<String, dynamic>) {
        companyData = data;
        nameController.text = (data['name'] as String?) ?? '';
        currency = (data['currency'] as String?)?.toUpperCase() ?? 'EGP';
        timezone = (data['timezone'] as String?) ?? 'Africa/Cairo';
        cycleStartDay = (data['cycle_start_day'] as num?)?.toInt() ?? 1;
        weekStartDay = (data['week_start_day'] as num?)?.toInt() ?? 6;

        // Auto-detect from the device when the company is still on the system
        // default ('Africa/Cairo' is the column default), so a fresh company
        // gets its real timezone without manual setup.
        if (timezone == 'Africa/Cairo') {
          final device = await _detectDeviceTimezone();
          if (device != null && device != timezone) {
            timezone = device;
            timezoneAutoDetected = true;
          }
        }
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void setCycleStartDay(int day) {
    cycleStartDay = day.clamp(1, 28);
    update();
  }

  void setWeekStartDay(int weekday) {
    weekStartDay = weekday.clamp(1, 7);
    update();
  }

  void setCurrency(String value) {
    currency = value;
    update();
  }

  void setTimezone(String value) {
    timezone = value;
    timezoneAutoDetected = false;
    update();
  }

  Future<void> saveSettings() async {
    status = StatusRequest.loading;
    update();

    final data = {
      'name': nameController.text.trim(),
      'currency': currency,
      'timezone': timezone,
      'cycle_start_day': cycleStartDay.clamp(1, 28),
      'week_start_day': weekStartDay.clamp(1, 7),
    };

    final response = await _companySettingsData.updateCompanySettings(data);

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'company_data_saved'.tr,
          snackPosition: SnackPosition.BOTTOM);
      status = StatusRequest.success;
    } else {
      Get.snackbar(
          'error'.tr, (response['message'] as String?) ?? 'an_error_occurred'.tr,
          snackPosition: SnackPosition.BOTTOM);
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }
}
