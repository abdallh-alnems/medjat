import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class StationData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> activate({
    required String qrPayload,
    required Map<String, dynamic> deviceInfo,
  }) async {
    return await _crud.postData(
      _stationUrl('/app/station/activate.php'),
      {
        'qr_payload': qrPayload,
        'device_info': deviceInfo,
      },
      auth: false,
    );
  }

  Future<Map<String, dynamic>> syncData() async {
    return await _crud.getData(
      _stationUrl('/app/station/sync.php'),
      useStationToken: true,
    );
  }

  Future<Map<String, dynamic>> branchEmployees() async {
    return await _crud.getData(
      _stationUrl('/app/station/branch_employees.php'),
      useStationToken: true,
    );
  }

  Future<Map<String, dynamic>> checkInOut({
    int? employeeId,
    required String method,
    double? confidence,
    double? gpsLat,
    double? gpsLng,
    String? capturedImageBase64,
    String? qrToken,
  }) async {
    final data = <String, dynamic>{
      'method': method,
    };
    if (employeeId != null) data['employee_id'] = employeeId;
    if (confidence != null) data['confidence'] = confidence;
    if (gpsLat != null) data['gps_lat'] = gpsLat;
    if (gpsLng != null) data['gps_lng'] = gpsLng;
    if (capturedImageBase64 != null) {
      data['captured_image_base64'] = capturedImageBase64;
    }
    if (qrToken != null) data['qr_token'] = qrToken;

    return await _crud.postData(
      _stationUrl('/app/station/check_in_out.php'),
      data,
      useStationToken: true,
    );
  }

  Future<Map<String, dynamic>> verifyAdminPin({
    required String pin,
  }) async {
    return await _crud.postData(
      _stationUrl('/app/station/verify_admin_pin.php'),
      {'pin': pin},
      useStationToken: true,
    );
  }

  Future<Map<String, dynamic>> enrollBiometric({
    required String adminPin,
    required int employeeId,
    List<double>? faceEmbedding,
  }) async {
    final data = <String, dynamic>{
      'admin_pin': adminPin,
      'employee_id': employeeId,
    };
    if (faceEmbedding != null) data['face_embedding'] = faceEmbedding;

    return await _crud.postData(
      _stationUrl('/app/station/enroll_employee_biometric.php'),
      data,
      useStationToken: true,
    );
  }

  Future<Map<String, dynamic>> matchFace({
    required List<double> embedding,
  }) async {
    return await _crud.postData(
      _stationUrl('/app/station/match_face.php'),
      {'embedding': embedding},
      useStationToken: true,
    );
  }

  Future<Map<String, dynamic>> heartbeat({
    double? gpsLat,
    double? gpsLng,
  }) async {
    final data = <String, dynamic>{};
    if (gpsLat != null) data['gps_lat'] = gpsLat;
    if (gpsLng != null) data['gps_lng'] = gpsLng;

    return await _crud.postData(
      _stationUrl('/app/station/heartbeat.php'),
      data,
      useStationToken: true,
    );
  }

  Future<Map<String, dynamic>> getMyStationQr() async {
    return await _crud.getData(
      AppLinks.myStationQr,
    );
  }

  String _stationUrl(String path) {
    final base = AppLinks.base;
    return '$base$path';
  }
}
