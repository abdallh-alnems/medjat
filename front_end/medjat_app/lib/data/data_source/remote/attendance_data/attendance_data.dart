import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class AttendanceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> checkIn({
    required int branchId,
    required double latitude,
    required double longitude,
    String? qrCode,
    bool isVpn = false,
  }) async {
    return await _crud.postData(AppLinks.checkIn, {
      'branch_id': branchId,
      'latitude': latitude,
      'longitude': longitude,
      // Empty when checking in by GPS only; the backend resolves the method
      // from the presence of a QR code.
      'qr_code': qrCode ?? '',
      'is_vpn': isVpn ? 1 : 0,
    });
  }

  Future<Map<String, dynamic>> checkOut() async {
    return await _crud.postData(AppLinks.checkOut, {});
  }

  /// Fetches the employee's own attendance records for a given `YYYY-MM` month.
  Future<Map<String, dynamic>> getMyAttendance(String month) async {
    return await _crud.getData(AppLinks.attendanceMonth(month));
  }

  Future<Map<String, dynamic>> syncOffline(List<Map<String, dynamic>> records) async {
    return await _crud.postData(AppLinks.attendanceSync, {
      'records': records,
    });
  }

  Future<Map<String, dynamic>> reportSecurityBlock({
    required int branchId,
    required String reason,
    required double latitude,
    required double longitude,
  }) async {
    return await _crud.postData(AppLinks.attendanceSecurityLog, {
      'branch_id': branchId,
      'reason': reason,
      'latitude': latitude,
      'longitude': longitude,
    });
  }
}
