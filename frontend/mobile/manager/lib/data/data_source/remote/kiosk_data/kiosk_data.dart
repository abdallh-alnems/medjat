import 'package:get/get.dart';

import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

/// Branch kiosks: the shared tablets employees clock in on.
///
/// Distinct from `DeviceData`, which handles third-party fingerprint terminals.
/// A kiosk runs our own app and authenticates as a **branch**, so everything
/// here is about the tablet's identity — pairing it, seeing it, and taking it
/// out of service — rather than about importing punches from hardware we do not
/// control.
///
/// Every call is POST, including the reads: writes require POST on this backend
/// and the reads stay consistent with their neighbours.
class KioskData {
  final CRUD _crud = Get.find<CRUD>();

  /// The fleet. Omit [branchId] for every branch in the company.
  ///
  /// The response carries `below_min_version` per station and a
  /// `would_block_count` — read them before raising the minimum version,
  /// because a directly-installed kiosk has no store to update itself from and
  /// raising it takes those branches offline until somebody visits them.
  Future<Map<String, dynamic>> list({int? branchId}) async {
    return await _crud.postData(AppLinks.kioskList, {
      'branch_id': ?branchId,
    });
  }

  /// Issues a pairing code for a branch.
  ///
  /// The plaintext comes back exactly once — the server stores only its hash —
  /// so it must be shown to the administrator immediately and never re-fetched.
  Future<Map<String, dynamic>> createPairingCode({
    required int branchId,
    String? name,
  }) async {
    return await _crud.postData(AppLinks.kioskCreatePairingCode, {
      'branch_id': branchId,
      if (name != null && name.isNotEmpty) 'name': name,
    });
  }

  /// Issues the six-digit code that opens a kiosk's administration area, where
  /// faces are enrolled and kiosk mode is released. Single use, five minutes.
  Future<Map<String, dynamic>> createAccessCode({required int stationId}) async {
    return await _crud.postData(AppLinks.kioskCreateAccessCode, {
      'station_id': stationId,
    });
  }

  /// Takes a tablet out of service.
  ///
  /// The station row survives — historical attendance points at it — and the
  /// device stops being served from its next request onwards, which is the only
  /// honest guarantee for a tablet that may be switched off.
  Future<Map<String, dynamic>> revoke({
    required int stationId,
    String? reason,
  }) async {
    return await _crud.postData(AppLinks.kioskRevoke, {
      'station_id': stationId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  /// Issues or resets an employee's personal kiosk code — the fallback for the
  /// day a face will not resolve. Returns the plaintext once.
  Future<Map<String, dynamic>> setEmployeeCode({
    required int employeeId,
    bool clear = false,
  }) async {
    return await _crud.postData(AppLinks.kioskSetPin, {
      'employee_id': employeeId,
      if (clear) 'clear': true,
    });
  }

  /// Identification attempts, including the ones that identified nobody.
  Future<Map<String, dynamic>> recognitionLogs({
    int? branchId,
    int? stationId,
    String? result,
    String? dateFrom,
    String? dateTo,
    int limit = 100,
  }) async {
    return await _crud.postData(AppLinks.kioskRecognitionLogs, {
      'view': 'list',
      'branch_id': ?branchId,
      'station_id': ?stationId,
      'result': ?result,
      'date_from': ?dateFrom,
      'date_to': ?dateTo,
      'limit': limit,
    });
  }

  /// The score histogram used to set the matching threshold and margin.
  ///
  /// Without reading this, the shipped defaults stay a guess: they were derived
  /// from a public face dataset, not from this company's branch.
  Future<Map<String, dynamic>> scoreDistribution({int? branchId}) async {
    return await _crud.postData(AppLinks.kioskRecognitionLogs, {
      'view': 'distribution',
      'branch_id': ?branchId,
    });
  }

  /// The capture behind one attempt. Costs `kiosk_evidence`, and every call is
  /// written to the audit log.
  Future<Map<String, dynamic>> capture({required int recognitionLogId}) async {
    return await _crud.postData(AppLinks.kioskCapture, {
      'recognition_log_id': recognitionLogId,
    });
  }
}
