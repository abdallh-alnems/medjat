import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/biometric_data/biometric_data.dart';
import '../../../data/model/biometric_enrollment_model.dart';

class FaceEnrollmentController extends GetxController {
  final BiometricData _data = Get.find<BiometricData>();

  StatusRequest status = StatusRequest.none;
  BiometricEnrollmentModel? enrollment;
  String? errorMessage;

  Future<void> loadStatus(int employeeId) async {
    status = StatusRequest.loading;
    update();
    final response = await _data.getStatus(employeeId);
    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is Map) {
        enrollment = BiometricEnrollmentModel.fromJson(Map<String, dynamic>.from(payload));
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  Future<bool> enrollFace(int employeeId, List<double> embedding,
      String imageBase64, double qualityScore) async {
    status = StatusRequest.loading;
    update();
    final response = await _data.enrollFace({
      'employee_id': employeeId,
      'embedding': embedding,
      'image_base64': imageBase64,
      'quality_score': qualityScore,
    });
    if (response['status'] == StatusRequest.success) {
      await loadStatus(employeeId);
      return true;
    }
    errorMessage = response['message'] as String?;
    status = StatusRequest.failure;
    update();
    return false;
  }

  Future<bool> deleteBiometric(int employeeId, String type) async {
    final response = await _data.delete(type, employeeId);
    if (response['status'] == StatusRequest.success) {
      await loadStatus(employeeId);
      return true;
    }
    return false;
  }
}
