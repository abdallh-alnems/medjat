import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/biometric_data/biometric_data.dart';
import '../../../data/model/biometric_enrollment_model.dart';

class FingerprintEnrollmentController extends GetxController {
  final BiometricData _data = Get.find<BiometricData>();

  StatusRequest status = StatusRequest.none;
  BiometricEnrollmentModel? enrollment;

  Future<void> loadStatus(int employeeId) async {
    final response = await _data.getStatus(employeeId);
    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is Map) {
        enrollment = BiometricEnrollmentModel.fromJson(Map<String, dynamic>.from(payload));
      }
    }
    update();
  }

  Future<bool> enrollFingerprint(int employeeId, String templateBase64) async {
    status = StatusRequest.loading;
    update();
    final response = await _data.enrollFingerprint({
      'employee_id': employeeId,
      'template_base64': templateBase64,
    });
    if (response['status'] == StatusRequest.success) {
      await loadStatus(employeeId);
      status = StatusRequest.success;
      update();
      return true;
    }
    status = StatusRequest.failure;
    update();
    return false;
  }
}
