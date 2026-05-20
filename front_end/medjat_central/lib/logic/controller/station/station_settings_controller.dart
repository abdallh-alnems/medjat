import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/station_data/station_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/model/station_settings_model.dart';
import '../../../data/model/branch_model.dart';

class StationSettingsController extends GetxController {
  final StationData _data = Get.find<StationData>();
  final BranchData _branchData = Get.find<BranchData>();

  StatusRequest status = StatusRequest.none;
  StationSettingsModel settings = StationSettingsModel();
  int branchId = 0;

  void init(int id) {
    branchId = id;
    loadSettings();
  }

  Future<void> loadSettings() async {
    status = StatusRequest.loading;
    update();
    final response = await _branchData.getBranch(branchId);
    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) payload = payload['data'];
      if (payload is Map) {
        final branch = BranchModel.fromJson(Map<String, dynamic>.from(payload));
        settings = StationSettingsModel(
          enabled: branch.stationEnabled,
          methods: branch.stationMethods,
          gpsRadiusMeters: branch.stationGpsRadiusMeters,
          confidenceThreshold: branch.stationConfidenceThreshold,
          antiSpoofing: branch.stationAntiSpoofing,
          hasAdminPin: branch.hasStationPin,
        );
      }
      status = StatusRequest.success;
    } else {
      status = StatusRequest.failure;
    }
    update();
  }

  Future<bool> saveSettings({
    bool? enabled,
    String? methods,
    int? gpsRadius,
    double? confidence,
    String? adminPin,
    bool? antiSpoofing,
  }) async {
    final data = <String, dynamic>{
      'branch_id': branchId,
    };
    if (enabled != null) data['station_enabled'] = enabled ? 1 : 0;
    if (methods != null) data['station_methods'] = methods;
    if (gpsRadius != null) data['station_gps_radius_meters'] = gpsRadius;
    if (confidence != null) data['station_confidence_threshold'] = confidence;
    if (adminPin != null) data['station_admin_pin'] = adminPin;
    if (antiSpoofing != null) data['station_anti_spoofing_enabled'] = antiSpoofing ? 1 : 0;

    final response = await _data.updateBranchSettings(data);
    if (response['status'] == StatusRequest.success) {
      await loadSettings();
      return true;
    }
    return false;
  }
}
