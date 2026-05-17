import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/app_links.dart';

class AttendanceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> checkIn({
    required String qrToken,
    required double lat,
    required double lng,
  }) async {
    return await _crud.postData(AppLinks.checkIn, {
      'qr_token': qrToken,
      'lat': lat,
      'lng': lng,
    });
  }

  Future<Map<String, dynamic>> checkOut({
    required String qrToken,
    required double lat,
    required double lng,
  }) async {
    return await _crud.postData(AppLinks.checkOut, {
      'qr_token': qrToken,
      'lat': lat,
      'lng': lng,
    });
  }

  Future<Map<String, dynamic>> syncOffline(List<Map<String, dynamic>> items) async {
    return await _crud.postData(AppLinks.attendanceSync, {
      'items': items,
    });
  }
}
