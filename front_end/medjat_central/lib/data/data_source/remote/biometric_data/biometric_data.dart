import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class BiometricData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> enrollFace(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.biometricEnrollFace, data);
  }

  Future<Map<String, dynamic>> enrollFingerprint(
      Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.biometricEnrollFingerprint, data);
  }

  Future<Map<String, dynamic>> delete(String type, int employeeId) async {
    return await _crud.postData(
      AppLinks.biometricDelete,
      {'employee_id': employeeId, 'type': type},
    );
  }

  Future<Map<String, dynamic>> getStatus(int employeeId) async {
    return await _crud.getData(AppLinks.biometricStatus(employeeId));
  }
}
