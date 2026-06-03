import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class StationData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> createStation(Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.stationCreate, data);
  }

  Future<Map<String, dynamic>> getStations({int? branchId}) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.stationList, queryParameters: params);
  }

  Future<Map<String, dynamic>> getStation(int id) async {
    return await _crud.getData(AppLinks.stationDetail(id));
  }

  Future<Map<String, dynamic>> updateStation(
      int id, Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.stationUpdate, {...data, 'id': id});
  }

  Future<Map<String, dynamic>> deleteStation(int id) async {
    return await _crud.postData(AppLinks.stationDelete, {'id': id});
  }

  Future<Map<String, dynamic>> regenerateQR(int id) async {
    return await _crud.postData(AppLinks.stationRegenerateQR, {'id': id});
  }

  Future<Map<String, dynamic>> unlockStation(int id) async {
    return await _crud.postData(AppLinks.stationUnlock, {'id': id});
  }

  Future<Map<String, dynamic>> getLogs({Map<String, dynamic>? filters}) async {
    return await _crud.getData(AppLinks.stationLogs,
        queryParameters: filters);
  }

  Future<Map<String, dynamic>> updateBranchSettings(
      Map<String, dynamic> data) async {
    return await _crud.postData(AppLinks.stationBranchSettings, data);
  }

  Future<Map<String, dynamic>> generateKioskPin(int stationId) async {
    return await _crud.postData(
        AppLinks.stationGenerateKioskPin, {'station_id': stationId});
  }
}
