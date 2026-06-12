import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class DeviceData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> register({
    required String fcmToken,
    String platform = 'android',
    String? deviceId,
    String? deviceModel,
    String? appVersion,
  }) async {
    return await _crud.postData(AppLinks.deviceRegister, {
      'fcm_token': fcmToken,
      'platform': platform,
      if (deviceId != null) 'device_id': deviceId,
      if (deviceModel != null) 'device_model': deviceModel,
      if (appVersion != null) 'app_version': appVersion,
    });
  }
}
