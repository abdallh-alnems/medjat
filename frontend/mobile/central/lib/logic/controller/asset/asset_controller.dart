import 'dart:async';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/asset_data/asset_data.dart';
import '../../../data/model/asset_custody_model.dart';

class AssetController extends GetxController {
  final AssetData _data = Get.find<AssetData>();

  StatusRequest status = StatusRequest.none;
  List<AssetCustodyModel> assets = [];
  String? statusFilter;

  @override
  void onInit() {
    super.onInit();
    loadAssets();
  }

  Future<void> loadAssets() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getAssets(status: statusFilter);

    if (response['status'] == StatusRequest.success) {
      assets = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  List<AssetCustodyModel> _extractItems(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] != null) {
      payload = payload['data'];
    }
    List<dynamic>? items;
    if (payload is List) {
      items = payload;
    } else if (payload is Map) {
      for (final key in const ['items', 'records', 'list', 'data']) {
        if (payload[key] is List) {
          items = payload[key] as List;
          break;
        }
      }
    }
    if (items == null) return [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(AssetCustodyModel.fromJson)
        .toList();
  }

  void filterByStatus(String? value) {
    statusFilter = value;
    loadAssets();
  }

  Future<void> approveReturn(int id) async {
    final response = await _data.approveReturn(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'asset_return_confirmed'.tr,
          snackPosition: SnackPosition.BOTTOM);
      unawaited(loadAssets());
    } else {
      _failSnack(response);
    }
  }

  Future<void> rejectReturn(int id, {String? reason}) async {
    final response = await _data.rejectReturn(id, reason: reason);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'asset_return_rejected'.tr,
          snackPosition: SnackPosition.BOTTOM);
      unawaited(loadAssets());
    } else {
      _failSnack(response);
    }
  }

  Future<bool> createAsset({
    required int employeeId,
    required String type,
    required String name,
    required DateTime assignedAt,
    double? value,
    String? serialNo,
    int quantity = 1,
    String? description,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      'employee_id': employeeId,
      'type': type,
      'name': name.trim(),
      'assigned_at': _fmt(assignedAt),
      'quantity': quantity,
      if (value != null && value > 0) 'value': value,
      if (serialNo != null && serialNo.trim().isNotEmpty)
        'serial_no': serialNo.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    final response = await _data.createAsset(data);
    if (response['status'] == StatusRequest.success) {
      // Snackbar is shown by the caller *after* closing the sheet — showing it
      // here would make Get.back() pop the snackbar instead of the sheet.
      unawaited(loadAssets());
      return true;
    }
    _failSnack(response, fallback: 'asset_create_failed'.tr);
    return false;
  }

  Future<bool> updateAsset({
    required int id,
    required String type,
    required String name,
    required DateTime assignedAt,
    double? value,
    String? serialNo,
    int quantity = 1,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      'type': type,
      'name': name.trim(),
      'assigned_at': _fmt(assignedAt),
      'quantity': quantity,
      'value': (value != null && value > 0) ? value : '',
      'serial_no': serialNo?.trim() ?? '',
      'notes': notes?.trim() ?? '',
    };

    final response = await _data.updateAsset(id, data);
    if (response['status'] == StatusRequest.success) {
      unawaited(loadAssets());
      return true;
    }
    _failSnack(response, fallback: 'asset_update_failed'.tr);
    return false;
  }

  Future<void> deleteAsset(int id) async {
    final response = await _data.deleteAsset(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'asset_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      unawaited(loadAssets());
    } else {
      _failSnack(response);
    }
  }

  void _failSnack(Map<String, dynamic> response, {String? fallback}) {
    final msg = response['message'];
    Get.snackbar('error'.tr, msg is String ? msg : (fallback ?? 'error'.tr),
        snackPosition: SnackPosition.BOTTOM);
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
