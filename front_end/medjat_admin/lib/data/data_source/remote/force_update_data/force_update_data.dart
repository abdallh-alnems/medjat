import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class ForceUpdateData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> trigger({
    required String minVersion,
    String platform = 'all',
    String message = 'Please update the app to continue',
  }) async {
    return await _crud.postData(AppLinks.forceUpdateTrigger, {
      'platform': platform,
      'min_version': minVersion,
      'message': message,
    });
  }
}
