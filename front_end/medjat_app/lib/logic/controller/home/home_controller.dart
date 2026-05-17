import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/location_service.dart';
import '../../../data/data_source/remote/home_data/home_data.dart';
import '../../../data/model/today_status_model.dart';

class HomeController extends GetxController {
  final HomeData _homeData = Get.find<HomeData>();

  StatusRequest status = StatusRequest.none;
  TodayStatusModel? todayStatus;
  double? distanceFromBranch;
  bool isOffline = false;

  StreamSubscription? _connectivitySub;

  @override
  void onInit() {
    super.onInit();
    loadTodayStatus();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    final connectivity = Get.find<ConnectivityService>();
    isOffline = !connectivity.isOnline;
    _connectivitySub = connectivity.onConnectivityChanged.listen((online) {
      final wasOffline = isOffline;
      isOffline = !online;
      if (online && wasOffline) {
        loadTodayStatus();
      }
      update();
    });
  }

  Future<void> loadTodayStatus() async {
    status = StatusRequest.loading;
    update();

    final response = await _homeData.getTodayStatus();
    final responseStatus = response['status'];

    if (responseStatus == StatusRequest.success) {
      final data = response['data'];
      if (data != null) {
        todayStatus = TodayStatusModel.fromJson(
          data is Map<String, dynamic> ? data : {},
        );
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
    if (isOffline && canCheckIn) return 'تسجيل الحضور (offline)';
    if (isOffline && canCheckOut) return 'تسجيل الانصراف (offline)';
    if (canCheckIn) return 'تسجيل الحضور';
    if (canCheckOut) return 'تسجيل الانصراف';
    return 'تم اليوم';
  }

  String get statusMessage {
    switch (attendanceStatus) {
      case AttendanceStatus.notCheckedIn:
        return 'لم يتم تسجيل الحضور';
      case AttendanceStatus.checkedIn:
        return 'مسجل الحضور';
      case AttendanceStatus.checkedOut:
        return 'تم اليوم';
    }
  }

  Future<void> startAttendanceFlow() async {
    if (isDayDone) return;

    final cameraStatus = await Permission.camera.status;
    if (cameraStatus.isDenied) {
      final result = await Permission.camera.request();
      if (result.isDenied || result.isPermanentlyDenied) {
        _showPermissionDialog('الكاميرا مطلوبة لمسح QR Code');
        return;
      }
    } else if (cameraStatus.isPermanentlyDenied) {
      _showPermissionDialog('الكاميرا مطلوبة لمسح QR Code');
      return;
    }

    final locationGranted = await LocationService.isPermissionGranted();
    if (!locationGranted) {
      final requested = await LocationService.requestPermission();
      if (!requested) {
        _showPermissionDialog('الموقع مطلوب لتأكيد حضورك');
        return;
      }
    }

    Get.toNamed(AppRoutes.scanQr);
  }

  void _showPermissionDialog(String message) {
    Get.dialog<void>(
      AlertDialog(
        title: const Text('صلاحية مطلوبة'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              openAppSettings();
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  void goToNotifications() {
    Get.toNamed(AppRoutes.notifications);
  }

  @override
  void onClose() {
    _connectivitySub?.cancel();
    super.onClose();
  }
}
