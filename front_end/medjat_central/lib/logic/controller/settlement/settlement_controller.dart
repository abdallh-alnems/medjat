import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/settlement_data/settlement_data.dart';
import '../../../data/model/settlement_model.dart';

class SettlementController extends GetxController {
  final SettlementData _data = Get.find<SettlementData>();

  final int employeeId;
  final String employeeName;

  SettlementController({required this.employeeId, required this.employeeName});

  StatusRequest status = StatusRequest.none;
  StatusRequest actionStatus = StatusRequest.none;

  /// The editable settlement (either the saved draft, or a fresh suggestion).
  SettlementModel settlement = SettlementModel();
  String employeeStatus = 'active';

  static const reasons = [
    'resignation',
    'termination',
    'end_of_contract',
    'retirement',
    'death',
    'absconding',
    'other',
  ];

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// Unwrap the {status, data:{status, data:{...}}} envelope to the inner map.
  Map<String, dynamic>? _payload(Map<String, dynamic> response) {
    final dynamic body = response['data'];
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.get(employeeId);
    if (response['status'] != StatusRequest.success) {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
      update();
      return;
    }

    final payload = _payload(response);
    final saved = payload?['settlement'];
    final suggested = payload?['suggested'];
    final emp = payload?['employee'];
    employeeStatus = (emp?['status'] as String?) ?? 'active';

    if (saved is Map<String, dynamic>) {
      settlement = SettlementModel.fromJson(saved);
    } else if (saved is Map) {
      settlement = SettlementModel.fromJson(Map<String, dynamic>.from(saved));
    } else if (suggested is Map) {
      settlement = SettlementModel.fromSuggested(
        Map<String, dynamic>.from(suggested),
        DateTime.now().toIso8601String().substring(0, 10),
      );
    } else {
      settlement = SettlementModel(
        lastWorkingDay: DateTime.now().toIso8601String().substring(0, 10),
      );
    }

    status = StatusRequest.success;
    update();
  }

  bool get isLocked => settlement.isApproved;
  bool get isAlreadyTerminated => employeeStatus == 'terminated';

  /// Recompute the auto figures for a new last working day (drafts only).
  Future<void> changeLastWorkingDay(String date) async {
    settlement.lastWorkingDay = date;
    update();
    if (isLocked) return;

    final response = await _data.preview(employeeId, date);
    if (response['status'] == StatusRequest.success) {
      final payload = _payload(response);
      final suggested = payload?['suggested'];
      if (suggested is Map) {
        settlement.applySuggested(Map<String, dynamic>.from(suggested));
      }
    }
    update();
  }

  void setReason(String reason) {
    settlement.reason = reason;
    update();
  }

  void editField(void Function(SettlementModel s) edit) {
    edit(settlement);
    update();
  }

  void addLineItem() {
    settlement.lineItems.add(SettlementLineItem());
    update();
  }

  void removeLineItem(int index) {
    if (index >= 0 && index < settlement.lineItems.length) {
      settlement.lineItems.removeAt(index);
      update();
    }
  }

  Future<bool> save() async {
    actionStatus = StatusRequest.loading;
    update();

    final response = await _data.save(settlement.toPayload(employeeId));
    actionStatus = StatusRequest.none;

    if (response['status'] == StatusRequest.success) {
      final payload = _payload(response);
      final saved = payload?['settlement'];
      if (saved is Map) {
        settlement = SettlementModel.fromJson(Map<String, dynamic>.from(saved));
      }
      Get.snackbar('done'.tr, 'settlement_saved'.tr,
          snackPosition: SnackPosition.BOTTOM);
      update();
      return true;
    }
    _failSnack(response, fallback: 'settlement_save_failed'.tr);
    update();
    return false;
  }

  Future<bool> approve() async {
    actionStatus = StatusRequest.loading;
    update();

    final response = await _data.approve(employeeId);
    actionStatus = StatusRequest.none;

    if (response['status'] == StatusRequest.success) {
      final payload = _payload(response);
      final saved = payload?['settlement'];
      if (saved is Map) {
        settlement = SettlementModel.fromJson(Map<String, dynamic>.from(saved));
      }
      employeeStatus = 'terminated';
      Get.snackbar('done'.tr, 'settlement_approved'.tr,
          snackPosition: SnackPosition.BOTTOM);
      update();
      return true;
    }
    _failSnack(response, fallback: 'settlement_approve_failed'.tr);
    update();
    return false;
  }

  Future<bool> markPaid() async {
    actionStatus = StatusRequest.loading;
    update();

    final response = await _data.markPaid(employeeId);
    actionStatus = StatusRequest.none;

    if (response['status'] == StatusRequest.success) {
      final payload = _payload(response);
      final saved = payload?['settlement'];
      if (saved is Map) {
        settlement = SettlementModel.fromJson(Map<String, dynamic>.from(saved));
      }
      Get.snackbar('done'.tr, 'settlement_marked_paid'.tr,
          snackPosition: SnackPosition.BOTTOM);
      update();
      return true;
    }
    _failSnack(response, fallback: 'error'.tr);
    update();
    return false;
  }

  void _failSnack(Map<String, dynamic> response, {String? fallback}) {
    final msg = response['message'];
    Get.snackbar('error'.tr, msg is String ? msg : (fallback ?? 'error'.tr),
        snackPosition: SnackPosition.BOTTOM);
  }
}
