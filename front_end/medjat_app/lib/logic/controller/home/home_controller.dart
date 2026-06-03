import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../data/data_source/remote/home_data/home_data.dart';
import '../../../data/model/today_status_model.dart';
import '../attendance/attendance_controller.dart';

class HomeController extends GetxController {
  final HomeData _homeData = Get.find<HomeData>();

  StatusRequest status = StatusRequest.none;
  TodayStatusModel? todayStatus;
  double? distanceFromBranch;
  bool isOffline = false;
  List<Map<String, dynamic>> monthRecords = [];

  StreamSubscription<bool>? _connectivitySub;

  @override
  void onInit() {
    super.onInit();
    loadTodayStatus();
    _listenToConnectivity();
    _tryInitialSync();
  }

  @override
  void onReady() {
    super.onReady();
    _maybeRequestNotificationPermission();
  }

  /// Ask for push-notification permission only after the home screen has
  /// rendered and settled — not the moment the user logs in. onReady fires
  /// after the first frame; a short delay lets the initial content land first.
  Future<void> _maybeRequestNotificationPermission() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await PushNotificationService.enableForUser();
  }

  Future<void> _tryInitialSync() async {
    try {
      final box = await Hive.openBox<dynamic>('offline_attendance');
      if (box.isEmpty) return;
      final online = await ConnectivityService.checkOnline();
      if (!online) return;
      _doSyncOffline();
    } catch (_) {}
  }

  void _doSyncOffline() {
    try {
      AttendanceController attendanceController;
      try {
        attendanceController = Get.find<AttendanceController>();
      } catch (_) {
        attendanceController = Get.put(AttendanceController());
      }
      attendanceController.syncOfflineRecords().then((_) {
        loadTodayStatus();
      });
    } catch (_) {}
  }

  void _listenToConnectivity() {
    final connectivity = Get.find<ConnectivityService>();
    isOffline = !connectivity.isOnline;
    _connectivitySub = connectivity.onConnectivityChanged.listen((online) {
      final wasOffline = isOffline;
      isOffline = !online;
      if (online && wasOffline) {
        _doSyncOffline();
        loadTodayStatus();
      }
      update();
    });
  }

  Future<void> loadTodayStatus() async {
    status = StatusRequest.loading;
    update();

    final now = DateTime.now();
    final month = DateFormat('yyyy-MM').format(now);

    final response = await _homeData.getAttendanceMonth(month);
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        final records = (data['records'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        monthRecords = records;

        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        final todayRecord = records.where((r) {
          final recordDate = r['date']?.toString();
          return recordDate == todayStr;
        }).toList();

        if (todayRecord.isNotEmpty) {
          final rec = todayRecord.first;
          todayStatus = TodayStatusModel.fromJson(rec);
        } else {
          todayStatus = TodayStatusModel(
            status: AttendanceStatus.notCheckedIn,
          );
        }
        _calculateDistance();
      }
      status = StatusRequest.success;
    } else if (responseStatus == StatusRequest.offline) {
      status = StatusRequest.offline;
      isOffline = true;
    } else {
      status = responseStatus ?? StatusRequest.failure;
    }

    update();
  }

  Future<void> _calculateDistance() async {
    if (todayStatus?.branchLat == null || todayStatus?.branchLng == null) {
      return;
    }
    try {
      final position = await LocationService().getCurrentPosition();
      distanceFromBranch = LocationService.distanceBetween(
        position.latitude,
        position.longitude,
        todayStatus!.branchLat!,
        todayStatus!.branchLng!,
      );
      update();
    } catch (_) {}
  }

  AttendanceStatus get attendanceStatus =>
      todayStatus?.status ?? AttendanceStatus.notCheckedIn;

  bool get canCheckIn => attendanceStatus == AttendanceStatus.notCheckedIn;
  bool get canCheckOut => attendanceStatus == AttendanceStatus.checkedIn;
  bool get isDayDone => attendanceStatus == AttendanceStatus.checkedOut;

  String get attendanceButtonText {
    if (isOffline && canCheckIn) return 'check_in_offline'.tr;
    if (isOffline && canCheckOut) return 'check_out_offline'.tr;
    if (canCheckIn) return 'check_in'.tr;
    if (canCheckOut) return 'check_out'.tr;
    return 'day_done'.tr;
  }

  String get statusMessage {
    switch (attendanceStatus) {
      case AttendanceStatus.notCheckedIn:
        return 'not_checked_in'.tr;
      case AttendanceStatus.checkedIn:
        return 'checked_in'.tr;
      case AttendanceStatus.checkedOut:
        return 'day_done'.tr;
    }
  }

  Future<void> startAttendanceFlow() async {
    if (isDayDone) return;

    final cameraStatus = await Permission.camera.status;
    if (cameraStatus.isDenied) {
      final result = await Permission.camera.request();
      if (result.isDenied || result.isPermanentlyDenied) {
        _showPermissionDialog('camera_required'.tr);
        return;
      }
    } else if (cameraStatus.isPermanentlyDenied) {
      _showPermissionDialog('camera_required'.tr);
      return;
    }

    final locationGranted = await LocationService.isPermissionGranted();
    if (!locationGranted) {
      final requested = await LocationService.requestPermission();
      if (!requested) {
        _showPermissionDialog('location_required'.tr);
        return;
      }
    }

    Get.toNamed<void>(AppRoutes.scanQr);
  }

  void _showPermissionDialog(String message) {
    Get.dialog<void>(
      AlertDialog(
        title: Text('permission_required'.tr),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () {
              Get.back<void>();
              openAppSettings();
            },
            child: Text('open_settings'.tr),
          ),
        ],
      ),
    );
  }

  void goToNotifications() {
    Get.toNamed<void>(AppRoutes.notifications);
  }

  @override
  void onClose() {
    _connectivitySub?.cancel();
    super.onClose();
  }
}
