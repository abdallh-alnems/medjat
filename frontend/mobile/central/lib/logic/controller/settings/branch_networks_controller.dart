import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';

/// One access point observed at a branch during its learning window.
class BranchNetworkSighting {
  final String bssid;
  final String? ssid;
  final int sightings;
  final int insideCount;
  final int outsideCount;
  final bool allInside;
  final bool allOutside;
  final int employeeCount;
  final bool isApproved;

  const BranchNetworkSighting({
    required this.bssid,
    this.ssid,
    required this.sightings,
    required this.insideCount,
    required this.outsideCount,
    required this.allInside,
    required this.allOutside,
    required this.employeeCount,
    required this.isApproved,
  });

  factory BranchNetworkSighting.fromJson(Map<String, dynamic> json) =>
      BranchNetworkSighting(
        bssid: json['bssid']?.toString() ?? '',
        ssid: json['ssid']?.toString(),
        sightings: (json['sightings'] as num?)?.toInt() ?? 0,
        insideCount: (json['inside_count'] as num?)?.toInt() ?? 0,
        outsideCount: (json['outside_count'] as num?)?.toInt() ?? 0,
        allInside: json['all_inside'] as bool? ?? false,
        allOutside: json['all_outside'] as bool? ?? false,
        employeeCount: (json['employee_count'] as num?)?.toInt() ?? 0,
        isApproved: json['is_approved'] as bool? ?? false,
      );
}

/// Drives the branch WiFi approval screen.
class BranchNetworksController extends GetxController {
  BranchNetworksController(this.branchId, this.branchName);

  final int branchId;
  final String branchName;

  final BranchData _branchData = Get.find<BranchData>();

  StatusRequest status = StatusRequest.none;
  List<BranchNetworkSighting> networks = [];
  Set<String> selected = {};
  String mode = 'learning';
  int totalSightings = 0;

  bool get willEnforce => mode == 'enforcing';

  /// Share of the window's check-ins that the current selection would still
  /// let through. This is what stops an admin enabling enforcement with a
  /// half-complete list and locking a floor out the next morning.
  double get coveragePercent {
    if (totalSightings == 0) return 0;
    final covered = networks
        .where((n) => selected.contains(n.bssid))
        .fold<int>(0, (sum, n) => sum + n.sightings);
    return (covered / totalSightings) * 100;
  }

  bool get isLowCoverage =>
      willEnforce && totalSightings > 0 && coveragePercent < 90;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final response = await _branchData.getBranchNetworks(branchId: branchId);
    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) data = data['data'];
      if (data is Map) {
        networks = ((data['networks'] as List?) ?? [])
            .map((e) =>
                BranchNetworkSighting.fromJson(e as Map<String, dynamic>))
            .toList();
        selected = networks.where((n) => n.isApproved).map((n) => n.bssid).toSet();
        mode = data['wifi_mode']?.toString() ?? 'learning';
        totalSightings = (data['total_sightings'] as num?)?.toInt() ?? 0;
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void toggle(String bssid) {
    if (!selected.remove(bssid)) selected.add(bssid);
    update();
  }

  void setMode(String value) {
    mode = value;
    update();
  }

  Future<bool> save() async {
    final response = await _branchData.approveBranchNetworks(
      branchId: branchId,
      approve: networks
          .where((n) => selected.contains(n.bssid))
          .map((n) => <String, dynamic>{
                'kind': 'bssid',
                'value': n.bssid,
                if (n.ssid != null) 'label': n.ssid,
              })
          .toList(),
      wifiMode: mode,
    );
    if (response['status'] == StatusRequest.success) {
      await load();
      return true;
    }
    return false;
  }
}
