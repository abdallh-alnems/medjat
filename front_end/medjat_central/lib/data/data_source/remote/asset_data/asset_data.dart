import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class AssetData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getAssets({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    return await _crud.getData(AppLinks.assets, queryParameters: params);
  }

  Future<Map<String, dynamic>> createAsset(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.assetCreate, data);
  }

  Future<Map<String, dynamic>> approveReturn(int id) async {
    return await _crud.postData(AppLinks.assetApproveReturn, {'id': id});
  }

  Future<Map<String, dynamic>> rejectReturn(int id, {String? reason}) async {
    return await _crud.postData(AppLinks.assetRejectReturn, {
      'id': id,
      if (reason != null) 'rejection_reason': reason,
    });
  }
}
