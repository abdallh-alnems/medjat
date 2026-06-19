import 'package:get/get.dart';
import '../../../core/class/api_messages.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/asset_data/asset_data.dart';

class AssetController extends GetxController {
  final AssetData _assetData = Get.find<AssetData>();

  StatusRequest myAssetsStatus = StatusRequest.none;
  List<Map<String, dynamic>> myAssets = [];

  @override
  void onInit() {
    super.onInit();
    loadMyAssets();
  }

  Future<void> loadMyAssets() async {
    myAssetsStatus = StatusRequest.loading;
    update();

    final response = await _assetData.myAssets();
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      myAssets = _extractItems(response['data']);
      myAssetsStatus = StatusRequest.success;
    } else {
      myAssetsStatus = responseStatus ?? StatusRequest.failure;
    }

    update();
  }

  List<Map<String, dynamic>> _extractItems(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    if (payload is Map) {
      for (final key in const ['items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          return (payload[key] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<bool> requestReturn(int id, {String? note}) async {
    final response = await _assetData.requestReturn(id, note: note);
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      Get.snackbar('success'.tr, 'asset_return_requested'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadMyAssets();
      return true;
    }

    // Map the backend's machine-readable code to a localized message; never
    // surface the raw server `message` to the user.
    Get.snackbar('error'.tr,
        ApiMessages.of(response, fallbackKey: 'asset_return_failed'),
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }
}
