import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';
import '../../../../core/services/network_service.dart';
import '../../../model/face_proof_model.dart';

class AttendanceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> checkIn({
    required int branchId,
    required double latitude,
    required double longitude,
    String? qrCode,
    bool isVpn = false,
    bool isMockLocation = false,
    bool isRootedDevice = false,
    FaceProof? faceProof,
    WifiInfo? wifi,
    bool wifiMethod = false,
    bool localBiometric = false,
    String? photoBase64,
  }) async {
    final data = <String, dynamic>{
      'branch_id': branchId,
      'latitude': latitude,
      'longitude': longitude,
      // Empty when checking in by GPS only; the backend resolves the method
      // from the presence of a QR code unless `method` says otherwise.
      'qr_code': qrCode ?? '',
      'is_vpn': isVpn ? 1 : 0,
      'is_mock_location': isMockLocation ? 1 : 0,
      'is_rooted_device': isRootedDevice ? 1 : 0,
      // Whether the device-biometric prompt was actually passed. Only companies
      // that opted in have it enforced server-side.
      'local_biometric': localBiometric ? 1 : 0,
    };
    if (faceProof != null) {
      data['method'] = 'face_selfie';
      data.addAll(faceProof.toJson());
    }
    if (wifiMethod) {
      data['method'] = 'wifi_gps';
    }
    // photo_gps. Set after the face branch on purpose: if a build ever sent
    // both, the face proof is the stronger claim and must win — declaring
    // photo_gps while carrying an embedding would tell the server to skip the
    // match it was about to make.
    if (photoBase64 != null && faceProof == null) {
      data['method'] = 'photo_gps';
      data['photo_base64'] = photoBase64;
    }
    // Always reported when known: during a branch's learning phase these are
    // what build its list of access points, even on other methods.
    if (wifi != null && wifi.isOnWifi) {
      data['wifi_bssid'] = wifi.bssid;
      if (wifi.ssid != null) data['wifi_ssid'] = wifi.ssid;
    }
    return await _crud.postData(AppLinks.checkIn, data);
  }

  Future<Map<String, dynamic>> checkOut({
    FaceProof? faceProof,
    WifiInfo? wifi,
    bool wifiMethod = false,
    bool isMockLocation = false,
    double? latitude,
    double? longitude,
    bool localBiometric = false,
    String? photoBase64,
  }) async {
    // Reported on check-out too: a company that rejects spoofed locations must
    // reject them at both ends, or leaving early from home stays possible.
    final data = <String, dynamic>{
      'is_mock_location': isMockLocation ? 1 : 0,
      'local_biometric': localBiometric ? 1 : 0,
    };
    if (latitude != null && longitude != null) {
      data['latitude'] = latitude;
      data['longitude'] = longitude;
    }
    if (faceProof != null) {
      data['method'] = 'face_selfie';
      data.addAll(faceProof.toJson());
    }
    if (wifiMethod) {
      data['method'] = 'wifi_gps';
    }
    // Same precedence as check-in: a face proof outranks a bare photo.
    if (photoBase64 != null && faceProof == null) {
      data['method'] = 'photo_gps';
      data['photo_base64'] = photoBase64;
    }
    if (wifi != null && wifi.isOnWifi) {
      data['wifi_bssid'] = wifi.bssid;
      if (wifi.ssid != null) data['wifi_ssid'] = wifi.ssid;
    }
    return await _crud.postData(AppLinks.checkOut, data);
  }

  /// Asks the server for a single-use liveness challenge. Called immediately
  /// before opening the camera — the nonce is short-lived on purpose.
  Future<Map<String, dynamic>> requestFaceChallenge({
    required String purpose,
  }) async {
    return await _crud.postData(AppLinks.faceChallenge, {'purpose': purpose});
  }

  Future<Map<String, dynamic>> faceStatus() async {
    return await _crud.postData(AppLinks.faceMyStatus, {});
  }

  /// One-time self-enrollment of the employee's own face.
  Future<Map<String, dynamic>> enrollFace({
    required List<double> embedding,
    required double qualityScore,
    required String nonce,
    required bool livenessPassed,
    String? imageBase64,
  }) async {
    return await _crud.postData(AppLinks.faceEnrollSelf, {
      'embedding': embedding,
      'quality_score': qualityScore,
      'face_nonce': nonce,
      'liveness_passed': livenessPassed,
      'image_base64': ?imageBase64,
    });
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
