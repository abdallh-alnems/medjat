import 'package:get/get.dart';

import '../../../core/class/api_messages.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/model/face_proof_model.dart';
import '../../../view/screen/attendance/widgets/face_capture_view.dart';

/// Owns the face challenge lifecycle and self-enrollment.
///
/// Kept separate from AttendanceController because a challenge is also needed
/// for enrollment, which is not an attendance action at all.
class FaceController extends GetxController {
  final AttendanceData _attendanceData = Get.find<AttendanceData>();

  StatusRequest status = StatusRequest.none;
  String? errorMessage;
  FaceChallengeModel? challenge;

  /// True when the last challenge request failed because there is no enrolled
  /// face — the caller should route to enrollment instead of showing an error.
  bool notEnrolled = false;

  /// Requests a fresh single-use challenge. Every attempt needs its own: the
  /// server burns the nonce on use, so a retry must never reuse the old one.
  Future<bool> requestChallenge({required String purpose}) async {
    status = StatusRequest.loading;
    errorMessage = null;
    notEnrolled = false;
    challenge = null;
    update();

    final response =
        await _attendanceData.requestFaceChallenge(purpose: purpose);

    if (response['status'] == StatusRequest.success) {
      final data = _unwrap(response);
      if (data != null) {
        challenge = FaceChallengeModel.fromJson(data);
        status = StatusRequest.success;
        update();
        return true;
      }
    }

    notEnrolled = _errorCode(response) == 'FACE_NOT_ENROLLED';
    errorMessage = ApiMessages.of(response);
    status = StatusRequest.failure;
    update();
    return false;
  }

  Future<bool> enroll(FaceCaptureResult result) async {
    final current = challenge;
    if (current == null) return false;

    status = StatusRequest.loading;
    errorMessage = null;
    update();

    final response = await _attendanceData.enrollFace(
      embedding: result.embedding,
      qualityScore: result.qualityScore,
      nonce: current.nonce,
      livenessPassed: result.livenessPassed,
      imageBase64: result.imageBase64,
    );

    if (response['status'] == StatusRequest.success) {
      status = StatusRequest.success;
      challenge = null;
      update();
      return true;
    }

    errorMessage = ApiMessages.of(response);
    status = StatusRequest.failure;
    // The nonce is spent whether or not enrollment succeeded, so clear it and
    // force the retry path to fetch a new one.
    challenge = null;
    update();
    return false;
  }

  void reset() {
    status = StatusRequest.none;
    errorMessage = null;
    challenge = null;
    notEnrolled = false;
    update();
  }

  static Map<String, dynamic>? _unwrap(Map<String, dynamic> response) {
    dynamic data = response['data'];
    if (data is Map && data['data'] is Map) data = data['data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// CRUD lifts the backend's `error_code` to the top level of the response.
  static String? _errorCode(Map<String, dynamic> response) =>
      response['error_code'] as String?;
}
