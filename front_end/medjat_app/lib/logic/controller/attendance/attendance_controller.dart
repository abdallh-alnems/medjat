import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/device_integrity_service.dart';
import '../../../core/services/location_service.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/model/today_status_model.dart';
import '../../../logic/controller/auth/auth_controller.dart';
import '../home/home_controller.dart';

class AttendanceController extends GetxController {
  final AttendanceData _attendanceData = Get.find<AttendanceData>();

  StatusRequest status = StatusRequest.none;
  bool isProcessing = false;
  String? errorMessage;

  Future<void> processQrScan(String qrCode) async {
    if (isProcessing) return;
    isProcessing = true;
    status = StatusRequest.loading;
    errorMessage = null;
    update();

    try {
      final position = await LocationService().getCurrentPosition();
      final homeController = Get.find<HomeController>();

      // --- device integrity check ---
      final integrity = await DeviceIntegrityService.check(position);
      if (integrity.isBlocking) {
        errorMessage = integrity.isMockLocation
            ? 'mock_location_detected'.tr
            : 'rooted_device_detected'.tr;
        status = StatusRequest.failure;
        unawaited(_attendanceData.reportSecurityBlock(
          branchId: homeController.todayStatus?.branchId ?? _getBranchId() ?? 0,
          reason: integrity.isMockLocation ? 'mock_location' : 'rooted',
          latitude: position.latitude,
          longitude: position.longitude,
        ));
        isProcessing = false;
        update();
        return;
      }

      if (integrity.isVpn) {
        Get.snackbar('vpn_warning'.tr, '');
      }

      final isCheckOut =
          homeController.attendanceStatus == AttendanceStatus.checkedIn;

      final isOnline = await ConnectivityService.checkOnline();

      if (isOnline) {
        await _processOnline(qrCode, position, isCheckOut, isVpn: integrity.isVpn);
      } else {
        await _processOffline(qrCode, position, isCheckOut, isVpn: integrity.isVpn);
      }
    } catch (e) {
      errorMessage = 'error_try_again'.tr;
      status = StatusRequest.failure;
    }

    isProcessing = false;
    update();
  }

  Future<void> _processOnline(
      String qrCode, Position position, bool isCheckOut, {bool isVpn = false}) async {
    final homeController = Get.find<HomeController>();

    final response = isCheckOut
        ? await _attendanceData.checkOut()
        : await _attendanceData.checkIn(
            branchId: homeController.todayStatus?.branchId ??
                _getBranchId() ??
                0,
            latitude: position.latitude,
            longitude: position.longitude,
            qrCode: qrCode,
            isVpn: isVpn,
          );

    final responseStatus = response['status'];

    if (responseStatus == StatusRequest.success) {
      status = StatusRequest.success;
      await homeController.loadTodayStatus();
      Get.offNamed<void>(
        AppRoutes.attendanceSuccess,
        arguments: {
          'is_check_out': isCheckOut,
          'offline': false,
          'data': response['data'],
        },
      );
    } else if (responseStatus == StatusRequest.offline) {
      await _processOffline(qrCode, position, isCheckOut, isVpn: isVpn);
    } else {
      final statusCode = response['statusCode'];
      if (statusCode == 422 || statusCode == 400) {
        final msg = (response['message'] as String?) ?? '';
        final errorCode = response['error_code'];
        if (msg.contains('range') ||
            msg.contains('بعيد') ||
            msg.contains('نطاق') ||
            errorCode == 'GPS_OUT_OF_RANGE') {
          errorMessage = 'out_of_range'.tr;
        } else if (msg.contains('QR') ||
            msg.contains('qr') ||
            msg.contains('غير صالح')) {
          errorMessage = 'invalid_qr'.tr;
        } else if (msg.contains('Already') || msg.contains('مسبقاً')) {
          errorMessage = 'already_checked_in'.tr;
        } else {
          errorMessage = msg;
        }
      } else if (statusCode == 409) {
        errorMessage = 'already_checked_in'.tr;
      } else {
        errorMessage =
            (response['message'] as String?) ?? 'error_try_again'.tr;
      }
      status = StatusRequest.failure;
    }
    update();
  }

  Future<void> _processOffline(
      String qrCode, Position position, bool isCheckOut, {bool isVpn = false}) async {
    final homeController = Get.find<HomeController>();
    final branch = homeController.todayStatus;

    if (branch != null &&
        branch.branchLat != null &&
        branch.branchLng != null &&
        branch.branchRadiusMeters != null) {
      final distance = LocationService.distanceBetween(
        position.latitude,
        position.longitude,
        branch.branchLat!,
        branch.branchLng!,
      );
      if (distance > branch.branchRadiusMeters!) {
        errorMessage = 'out_of_range'.tr;
        status = StatusRequest.failure;
        update();
        return;
      }
    }

    await _saveOfflineRecord(
      qrCode: qrCode,
      position: position,
      isCheckOut: isCheckOut,
      isVpn: isVpn,
    );

      Get.offNamed<void>(
      AppRoutes.attendanceSuccess,
      arguments: {
        'is_check_out': isCheckOut,
        'offline': true,
      },
    );
    status = StatusRequest.success;
    update();
  }

  Future<void> _saveOfflineRecord({
    required String qrCode,
    required Position position,
    required bool isCheckOut,
    bool isVpn = false,
  }) async {
    final box = await Hive.openBox<dynamic>('offline_attendance');
    final branchId = _getBranchId() ?? 0;
    final now = DateTime.now();

    final existingIndex = box.values.toList().indexWhere((r) {
      final recordDate = (r as Map)['date'] as String?;
      return recordDate == now.toIso8601String().substring(0, 10);
    });

    final record = {
      'client_record_id': now.millisecondsSinceEpoch.toString(),
      'branch_id': branchId,
      'date': now.toIso8601String().substring(0, 10),
      'captured_at': now.toIso8601String(),
      'qr_code': qrCode,
      'is_vpn': isVpn ? 1 : 0,
      'check_in_latitude': position.latitude,
      'check_in_longitude': position.longitude,
      if (!isCheckOut) 'check_in_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
      if (isCheckOut) 'check_out_time': '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
    };

    if (existingIndex >= 0) {
      await box.putAt(existingIndex, record);
    } else {
      await box.add(record);
    }
  }

  Future<void> syncOfflineRecords() async {
    final box = await Hive.openBox<dynamic>('offline_attendance');
    if (box.isEmpty) return;

    final records = box.values.map((r) => Map<String, dynamic>.from(r as Map)).toList();

    final response = await _attendanceData.syncOffline(records);
    if (response['status'] == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      final results = (data?['results'] as List<dynamic>?) ?? [];
      final syncedIds = <String>{};
      for (final r in results) {
        if (r is Map<String, dynamic> && r['status'] == 'synced') {
          final id = r['client_record_id']?.toString();
          if (id != null) syncedIds.add(id);
        }
      }
      if (syncedIds.isNotEmpty) {
        final keysToDelete = <dynamic>[];
        for (int i = 0; i < box.length; i++) {
          final record = box.getAt(i);
          if (record is Map && syncedIds.contains(record['client_record_id']?.toString())) {
            keysToDelete.add(box.keyAt(i));
          }
        }
        for (final key in keysToDelete) {
          await box.delete(key);
        }
      }
    }
  }

  int? _getBranchId() {
    try {
      final authController = Get.find<AuthController>();
      return authController.user?.branchId;
    } catch (_) {
      return null;
    }
  }

  void showError(String message) {
    errorMessage = message;
    status = StatusRequest.failure;
    update();
  }

  void reset() {
    status = StatusRequest.none;
    isProcessing = false;
    errorMessage = null;
    update();
  }
}
