import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/kiosk_data/kiosk_data.dart';
import '../../../data/model/branch_model.dart';

/// The branch kiosk fleet.
///
/// Two things here are not obvious from the API surface and are worth stating,
/// because both are easy to get wrong in a UI:
///
///  * **Codes are shown once.** Pairing and access codes come back in plaintext
///    exactly once; the server stores only their hashes. A screen that loses
///    one has to issue a new one, and a screen that caches one is storing a
///    credential it should not have.
///  * **Raising the minimum version takes tablets offline.** Unlike the store
///    apps, a directly-installed kiosk has nowhere to be sent for an update, so
///    `wouldBlockCount` has to be visible *before* anybody changes it.
class KioskFleetController extends GetxController {
  final KioskData _kioskData = Get.find<KioskData>();
  final BranchData _branchData = Get.find<BranchData>();

  StatusRequest status = StatusRequest.none;
  bool saving = false;

  List<Map<String, dynamic>> stations = [];
  List<Map<String, dynamic>> rosters = [];
  List<BranchModel> branches = [];

  String minVersion = '0.0.0';
  int wouldBlockCount = 0;

  /// The version gate answered from cache because Firebase was unreachable.
  /// Worth showing: it means the number on screen may be stale.
  bool versionGateStale = false;

  int? filterBranchId;

  int get offlineCount => stations.where((s) => s['is_offline'] == true).length;

  int get activeCount => stations.where((s) => s['status'] == 'active').length;

  /// Branches whose enrolled roster has passed the size at which face-only
  /// identification can still hold its accuracy target.
  List<Map<String, dynamic>> get rostersOverCeiling =>
      rosters.where((r) => r['over_ceiling'] == true).toList();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final results = await Future.wait([
      _kioskData.list(branchId: filterBranchId),
      _branchData.getBranches(),
    ]);

    final kioskResponse = results[0];
    if (kioskResponse['status'] == StatusRequest.success) {
      final data = _unwrap(kioskResponse['data']);
      if (data is Map) {
        stations = _mapList(data['stations']);
        rosters = _mapList(data['rosters']);
        minVersion = data['min_version'] as String? ?? '0.0.0';
        wouldBlockCount = (data['would_block_count'] as num?)?.toInt() ?? 0;
        versionGateStale = data['version_gate_stale'] == true;
      }
      status = StatusRequest.success;
    } else {
      status = kioskResponse['status'] as StatusRequest;
    }

    final branchResponse = results[1];
    if (branchResponse['status'] == StatusRequest.success) {
      final data = _unwrap(branchResponse['data']);
      final list = data is Map ? data['branches'] : null;
      branches = list is List
          ? list
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => BranchModel.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : [];
    }

    update();
  }

  void setBranchFilter(int? branchId) {
    filterBranchId = branchId;
    load();
  }

  /// Issues a pairing code. Returns the plaintext, or null on failure.
  ///
  /// The caller must display it immediately — it cannot be fetched again.
  Future<String?> createPairingCode({
    required int branchId,
    String? name,
  }) async {
    saving = true;
    update();

    final response = await _kioskData.createPairingCode(
      branchId: branchId,
      name: name,
    );

    saving = false;
    update();

    if (response['status'] != StatusRequest.success) {
      _failure(response, fallback: 'kiosk_pair_branch_disabled'.tr);
      return null;
    }

    final data = _unwrap(response['data']);
    return data is Map ? data['code'] as String? : null;
  }

  /// Issues the code that opens a kiosk's settings. Shown once.
  Future<String?> createAccessCode({required int stationId}) async {
    saving = true;
    update();

    final response = await _kioskData.createAccessCode(stationId: stationId);

    saving = false;
    update();

    if (response['status'] != StatusRequest.success) {
      _failure(response);
      return null;
    }

    final data = _unwrap(response['data']);
    return data is Map ? data['code'] as String? : null;
  }

  Future<bool> revoke({required int stationId, String? reason}) async {
    saving = true;
    update();

    final response = await _kioskData.revoke(stationId: stationId, reason: reason);

    saving = false;
    update();

    if (response['status'] != StatusRequest.success) {
      _failure(response);
      return false;
    }

    await load();
    return true;
  }

  static List<Map<String, dynamic>> _mapList(dynamic raw) => raw is List
      ? raw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : <Map<String, dynamic>>[];

  static dynamic _unwrap(dynamic data) =>
      data is Map && data.containsKey('data') ? data['data'] : data;

  void _failure(Map<String, dynamic> response, {String? fallback}) {
    final data = _unwrap(response['data']);
    final message = data is Map ? data['message'] as String? : null;

    Get.snackbar(
      'error'.tr,
      message ?? fallback ?? 'generic_error'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
    );
  }
}
