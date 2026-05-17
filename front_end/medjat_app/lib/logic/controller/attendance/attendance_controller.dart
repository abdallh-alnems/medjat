import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/location_service.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/model/today_status_model.dart';
import '../home/home_controller.dart';

class AttendanceController extends GetxController {
  final AttendanceData _attendanceData = Get.find<AttendanceData>();

  StatusRequest status = StatusRequest.none;
  bool isProcessing = false;
  String? errorMessage;

  Future<void> processQrScan(String qrToken) async {
    if (isProcessing) return;
    isProcessing = true;
    status = StatusRequest.loading;
    errorMessage = null;
    update();

    try {
      final position = await LocationService().getCurrentPosition();
      final homeController = Get.find<HomeController>();
      final isCheckOut =
          homeController.attendanceStatus == AttendanceStatus.checkedIn;

      final isOnline = await ConnectivityService.checkOnline();

      if (isOnline) {
        await _processOnline(qrToken, position, isCheckOut);
      } else {
        await _processOffline(qrToken, position, isCheckOut);
      }
    } on PlatformException catch (e) {
      if (e.code == 'LOCATION_PERMISSION_DENIED' ||
          e.code == 'LOCATION_PERMISSION_PERMANENTLY_DENIED') {
        errorMessage = 'صلاحية الموقع مرفوضة، افتح الإعدادات';
        status = StatusRequest.failure;
      } else {
        errorMessage = 'حدث خطأ في تحديد الموقع';
        status = StatusRequest.failure;
      }
    } catch (e) {
      errorMessage = 'حدث خطأ، حاول مرة أخرى';
      status = StatusRequest.failure;
    }

    isProcessing = false;
    update();
  }

  Future<void> _processOnline(
      String qrToken, Position position, bool isCheckOut) async {
    final response = isCheckOut
        ? await _attendanceData.checkOut(
            qrToken: qrToken,
            lat: position.latitude,
            lng: position.longitude,
          )
        : await _attendanceData.checkIn(
            qrToken: qrToken,
            lat: position.latitude,
            lng: position.longitude,
          );

    final responseStatus = response['status'];

    if (responseStatus == StatusRequest.success) {
      status = StatusRequest.success;
      final homeController = Get.find<HomeController>();
      await homeController.loadTodayStatus();
      Get.offNamed(
        AppRoutes.attendanceSuccess,
        arguments: {
          'is_check_out': isCheckOut,
          'offline': false,
          'data': response['data'],
        },
      );
    } else if (responseStatus == StatusRequest.offline) {
      await _processOffline(qrToken, position, isCheckOut);
    } else {
      final statusCode = response['statusCode'];
      if (statusCode == 422) {
        final msg = response['message'] ?? '';
        if (msg.contains('range') || msg.contains('بعيد') || msg.contains('نطاق')) {
          errorMessage = 'أنت خارج نطاق الفرع';
        } else if (msg.contains('QR') || msg.contains('qr') || msg.contains('غير صالح')) {
          errorMessage = 'QR Code غير صالح';
        } else {
          errorMessage = msg;
        }
      } else if (statusCode == 409) {
        errorMessage = 'تم تسجيل الحضور مسبقاً';
      } else {
        errorMessage = response['message'] ?? 'حدث خطأ، حاول مرة أخرى';
      }
      status = StatusRequest.failure;
    }
    update();
  }

  Future<void> _processOffline(
      String qrToken, Position position, bool isCheckOut) async {
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
        errorMessage = 'أنت خارج نطاق الفرع';
        status = StatusRequest.failure;
        update();
        return;
      }
    }

    Get.offNamed(
      AppRoutes.attendanceSuccess,
      arguments: {
        'is_check_out': isCheckOut,
        'offline': true,
      },
    );
    status = StatusRequest.success;
    update();
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
