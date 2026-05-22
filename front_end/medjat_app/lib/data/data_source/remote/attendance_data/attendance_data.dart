import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class AttendanceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> checkIn({
    required int branchId,
    required double latitude,
    required double longitude,
    required String qrCode,
  }) async {
    return await _crud.postData(AppLinks.checkIn, {
      'branch_id': branchId,
      'latitude': latitude,
      'longitude': longitude,
      'qr_code': qrCode,
    });
  }

  Future<Map<String, dynamic>> checkOut() async {
    return await _crud.postData(AppLinks.checkOut, {});
  }

  Future<Map<String, dynamic>> syncOffline(List<Map<String, dynamic>> records) async {
    return await _crud.postData(AppLinks.attendanceSync, {
      'records': records,
    });
  }
}
