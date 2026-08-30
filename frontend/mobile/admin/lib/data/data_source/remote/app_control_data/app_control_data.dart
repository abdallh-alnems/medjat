import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class AppControlData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> get() async {
    return await _crud.getData(AppLinks.appControlGet);
  }

  Future<Map<String, dynamic>> set({
    required String app,
    String? minVersion,
    bool? maintenance,
  }) async {
    final data = <String, dynamic>{'app': app};
    if (minVersion != null) data['min_version'] = minVersion;
    if (maintenance != null) data['maintenance'] = maintenance;
    return await _crud.postData(AppLinks.appControlSet, data);
  }
}
