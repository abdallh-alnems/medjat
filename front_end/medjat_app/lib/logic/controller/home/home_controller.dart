import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive/hive.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../data/data_source/remote/home_data/home_data.dart';
import '../../../data/model/attendance_config_model.dart';
import '../../../data/model/today_status_model.dart';
import '../../../view/screen/home/widgets/attendance_method_picker_sheet.dart';
import '../attendance/attendance_controller.dart';

class HomeController extends GetxController {
  final HomeData _homeData = Get.find<HomeData>();

  StatusRequest status = StatusRequest.none;
  TodayStatusModel? todayStatus;
  AttendanceConfigModel attendanceConfig = const AttendanceConfigModel();
  double? distanceFromBranch;
  bool isOffline = false;
  List<Map<String, dynamic>> monthRecords = [];

  // Today's expected attendance window, as configured by management.
  String? shiftStart;
  String? shiftEnd;
  bool isRestDay = false;

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
    // Build date strings with ASCII digits explicitly. The app locale is Arabic,
    // so DateFormat().format() emits Arabic-Indic digits (٢٠٢٦-٠٦) which the
    // backend can't match — returning zero records and a wrong "not checked in".
    String two(int n) => n.toString().padLeft(2, '0');
    final month = '${now.year}-${two(now.month)}';

    final response = await _homeData.getAttendanceMonth(month);
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        final configJson = data['attendance_config'] as Map<String, dynamic>?;
        if (configJson != null) {
          attendanceConfig = AttendanceConfigModel.fromJson(configJson);
        }
        final shiftJson = data['today_shift'] as Map<String, dynamic>?;
        if (shiftJson != null) {
          shiftStart = shiftJson['start_time'] as String?;
          shiftEnd = shiftJson['end_time'] as String?;
          isRestDay = shiftJson['is_rest_day'] == true ||
              shiftJson['is_rest_day'] == 1 ||
              shiftJson['is_rest_day'] == '1';
        }
        final records = (data['records'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        monthRecords = records;

        final todayStr = '${now.year}-${two(now.month)}-${two(now.day)}';
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
        unawaited(_calculateDistance());
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

  /// Management-configured attendance window for today, e.g. "09:00 - 17:00".
  /// Null when there's no schedule or today is a rest day.
  String? get scheduledTimeText {
    if (isRestDay || shiftStart == null) return null;
    String hm(String t) => t.length >= 5 ? t.substring(0, 5) : t;
    final start = hm(shiftStart!);
    if (shiftEnd == null) return start;
    return '$start - ${hm(shiftEnd!)}';
  }

  AttendanceStatus get attendanceStatus =>
      todayStatus?.status ?? AttendanceStatus.notCheckedIn;

  bool get canCheckIn => attendanceStatus == AttendanceStatus.notCheckedIn;
  bool get canCheckOut => attendanceStatus == AttendanceStatus.checkedIn;
  bool get isDayDone => attendanceStatus == AttendanceStatus.checkedOut;

  String get attendanceButtonText {
    if (isDayDone) return 'day_done'.tr;
    if (attendanceConfig.isSelfCheckDisabled) {
      return 'attendance_via_admin'.tr;
    }
    if (isOffline && canCheckIn) return 'check_in_offline'.tr;
    if (isOffline && canCheckOut) return 'check_out_offline'.tr;
    if (canCheckIn) return 'check_in'.tr;
    if (canCheckOut) return 'check_out'.tr;
    return 'day_done'.tr;
  }

  IconData get attendanceButtonIcon {
    if (isDayDone) return Icons.check_rounded;
    final config = attendanceConfig;
    if (config.isSelfCheckDisabled) {
      return Icons.manage_accounts_outlined;
    }
    if (config.selfMethods.length > 1) return Icons.touch_app_outlined;
    return config.hasGpsOnly && !config.hasQrGps
        ? Icons.location_on_outlined
        : Icons.qr_code_scanner;
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

    final config = attendanceConfig;

    // Branch only allows manual check-in — the employee can't self check-in.
    if (config.isSelfCheckDisabled) {
      _showMethodUnavailableDialog();
      return;
    }

    final selfMethods = config.selfMethods;

    // Multiple methods enabled — let the employee pick.
    if (selfMethods.length > 1) {
      AttendanceMethodPickerSheet.show(
        methods: selfMethods,
        onSelected: _startMethod,
      );
      return;
    }

    await _startMethod(selfMethods.first);
  }

  Future<void> _startMethod(String method) async {
    if (method == 'gps_only') {
      if (!await _ensureLocationPermission()) return;
      unawaited(Get.toNamed<void>(AppRoutes.gpsCheckIn));
    } else {
      if (!await _ensureCameraPermission()) return;
      if (!await _ensureLocationPermission()) return;
      unawaited(Get.toNamed<void>(AppRoutes.scanQr));
    }
  }

  Future<bool> _ensureCameraPermission() async {
    final cameraStatus = await Permission.camera.status;
    if (cameraStatus.isDenied) {
      final result = await Permission.camera.request();
      if (result.isDenied || result.isPermanentlyDenied) {
        _showPermissionDialog('camera_required'.tr);
        return false;
      }
    } else if (cameraStatus.isPermanentlyDenied) {
      _showPermissionDialog('camera_required'.tr);
      return false;
    }
    return true;
  }

  Future<bool> _ensureLocationPermission() async {
    final locationGranted = await LocationService.isPermissionGranted();
    if (!locationGranted) {
      final requested = await LocationService.requestPermission();
      if (!requested) {
        _showPermissionDialog('location_required'.tr);
        return false;
      }
    }
    return true;
  }

  void _showMethodUnavailableDialog() {
    Get.dialog<void>(
      AlertDialog(
        title: Text('attendance_manual_title'.tr),
        content: Text('attendance_manual_desc'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('got_it'.tr),
          ),
        ],
      ),
    );
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
