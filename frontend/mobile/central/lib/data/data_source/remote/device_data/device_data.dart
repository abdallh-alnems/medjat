import 'dart:io';

import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

/// Biometric attendance terminals: registering them, linking their User IDs to
/// employees, and reading the raw punch feed.
class DeviceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getDevices() async {
    return await _crud.getData(AppLinks.devices);
  }

  /// Claims a terminal by the serial number printed on it.
  Future<Map<String, dynamic>> registerDevice({
    required String serialNumber,
    required int branchId,
    String? name,
  }) async {
    // POST (not PUT): the backend uses POST and PUT is unreliable on the host.
    return await _crud.postData(AppLinks.deviceRegister, {
      'serial_number': serialNumber,
      'branch_id': branchId,
      if (name != null && name.isNotEmpty) 'name': name,
    });
  }

  /// Imports a punch export from any terminal, of any brand, by file.
  ///
  /// [preview] parses and reports without writing anything — always run it
  /// first, so the admin can check how the dates were read before committing.
  /// Pass [deviceId] for a registered terminal, or [branchId] to file the
  /// punches against a branch that has none.
  Future<Map<String, dynamic>> importPunches({
    required File file,
    int? deviceId,
    int? branchId,
    bool preview = false,
  }) async {
    return await _crud.postFile(
      AppLinks.deviceImportPunches,
      file,
      fields: {
        if (deviceId != null) 'device_id': '$deviceId',
        if (branchId != null) 'branch_id': '$branchId',
        'preview': preview ? '1' : '0',
      },
    );
  }

  /// Only the keys present are changed; everything else is left alone.
  Future<Map<String, dynamic>> updateDevice({
    required int deviceId,
    String? name,
    int? branchId,
    String? status,
    String? directionMode,
    int? minIntervalSeconds,
    int? clockOffsetMinutes,
    bool? debugLogging,
  }) async {
    return await _crud.patchData(AppLinks.deviceUpdate(deviceId), {
      'name': ?name,
      'branch_id': ?branchId,
      'status': ?status,
      'direction_mode': ?directionMode,
      'min_interval_seconds': ?minIntervalSeconds,
      'clock_offset_minutes': ?clockOffsetMinutes,
      'debug_logging': ?debugLogging});
  }

  Future<Map<String, dynamic>> releaseDevice(int deviceId) async {
    return await _crud.deleteData(AppLinks.deviceDelete(deviceId));
  }

  Future<Map<String, dynamic>> getDeviceUsers(int deviceId, {String? filter}) {
    return _crud.getData(AppLinks.deviceUsers(deviceId, filter: filter));
  }

  /// Links a terminal User ID to an employee. Pass a null employee to unlink.
  Future<Map<String, dynamic>> linkUser({
    required int deviceUserRowId,
    required int? employeeId,
  }) async {
    return await _crud.postData(AppLinks.deviceLinkUser, {
      'device_user_row_id': deviceUserRowId,
      'employee_id': employeeId,
    });
  }

  Future<Map<String, dynamic>> getPunches({
    int? deviceId,
    String? state,
    int limit = 100,
  }) async {
    return await _crud.getData(
      AppLinks.devicePunches(deviceId: deviceId, state: state, limit: limit),
    );
  }

  /// Queues a command the terminal collects on its next poll: sync_time,
  /// reboot, info.
  Future<Map<String, dynamic>> sendCommand({
    required int deviceId,
    required String kind,
  }) async {
    return await _crud.postData(AppLinks.deviceCommand, {
      'device_id': deviceId,
      'kind': kind,
    });
  }
}
