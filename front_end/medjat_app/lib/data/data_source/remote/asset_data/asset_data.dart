import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class AssetData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> myAssets({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    return await _crud.getData(AppLinks.myAssets, queryParameters: params);
  }

  Future<Map<String, dynamic>> requestReturn(int id, {String? note}) async {
    final data = <String, dynamic>{'id': id};
    if (note != null && note.trim().isNotEmpty) {
      data['return_note'] = note.trim();
    }
    return await _crud.postData(AppLinks.assetRequestReturn, data);
  }
}
