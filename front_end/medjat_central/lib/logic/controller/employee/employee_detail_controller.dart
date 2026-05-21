import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/class/crud.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/id/app_links.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/data_source/remote/document_data/document_data.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';
import '../../../data/data_source/remote/leave_data/leave_data.dart';
import '../../../data/data_source/remote/performance_data/performance_data.dart';
import '../../../data/model/employee_model.dart';
import '../../../data/model/attendance_model.dart';
import '../../../data/model/document_model.dart';
import '../../../data/model/warning_model.dart';
import '../../../data/model/performance_review_model.dart';
import '../../controller/auth/auth_controller.dart';

class EmployeeDetailController extends GetxController {
  final EmployeeData _employeeData = Get.find<EmployeeData>();
  final AttendanceData _attendanceData = Get.find<AttendanceData>();
  final DocumentData _documentData = Get.find<DocumentData>();
  final PayrollData _payrollData = Get.find<PayrollData>();
  final LeaveData _leaveData = Get.find<LeaveData>();
  final PerformanceData _performanceData = Get.find<PerformanceData>();
  final CRUD _crud = Get.find<CRUD>();

  StatusRequest status = StatusRequest.none;
  StatusRequest attendanceStatus = StatusRequest.none;
  StatusRequest documentsStatus = StatusRequest.none;
  StatusRequest activationStatus = StatusRequest.none;
  StatusRequest adjustmentStatus = StatusRequest.none;
  StatusRequest warningStatus = StatusRequest.none;
  StatusRequest conversionStatus = StatusRequest.none;
  StatusRequest reviewStatus = StatusRequest.none;

  EmployeeModel? employee;
  List<AttendanceRecordModel> attendanceRecords = [];
  List<DocumentModel> documents = [];
  List<WarningModel> warnings = [];
  List<PerformanceReviewModel> reviews = [];
  List<Map<String, dynamic>> categories = [];

  int leaveUsed = 0;
  int leaveRemaining = 0;
  int leaveTotal = 0;
  int leaveCarriedOver = 0;
  int leaveEntitlement = 0;
  int leaveYear = 0;
  bool get hasLeaveBalance => leaveTotal > 0;

  String? activationCode;
  DateTime? activationExpiresAt;
  bool deviceBound = false;
  String? deviceModel;
  String? devicePlatform;
  DateTime? deviceLastUsedAt;

  final int employeeId;

  EmployeeDetailController({required this.employeeId});

  @override
  void onInit() {
    super.onInit();
    loadEmployee();
    loadAttendance();
    loadDocuments();
    loadReviews();
  }

  Future<void> loadEmployee() async {
    status = StatusRequest.loading;
    update();

    final response = await _employeeData.getEmployee(employeeId);

    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map<String, dynamic>) {
        if (data['employee'] is Map<String, dynamic>) {
          employee = EmployeeModel.fromJson(data['employee'] as Map<String, dynamic>);
        }
        _applyActivationPayload(data);
        if (data['warnings'] is List) {
          warnings = (data['warnings'] as List)
              .map((e) => WarningModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        if (data['leave_balance'] is Map<String, dynamic>) {
          final lb = data['leave_balance'] as Map<String, dynamic>;
          leaveYear = (lb['year'] as num?)?.toInt() ?? 0;
          leaveUsed = (lb['used_days'] as num?)?.toInt() ?? 0;
          leaveRemaining = (lb['remaining_days'] as num?)?.toInt() ?? 0;
          leaveTotal = (lb['total_days'] as num?)?.toInt() ?? 0;
          leaveCarriedOver = (lb['carried_over_days'] as num?)?.toInt() ?? 0;
          leaveEntitlement = (lb['entitlement_days'] as num?)?.toInt() ?? 0;
        }
        if (data['categories'] is List) {
          categories = (data['categories'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> loadAttendance() async {
    attendanceStatus = StatusRequest.loading;
    update();

    final response = await _attendanceData.getAttendance(
      employeeId: employeeId,
    );

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is List) {
        attendanceRecords = data
            .map((e) => AttendanceRecordModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      attendanceStatus = StatusRequest.success;
    } else {
      attendanceStatus =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> loadDocuments() async {
    documentsStatus = StatusRequest.loading;
    update();

    final response = await _documentData.getDocuments(employeeId);

    if (response['status'] == StatusRequest.success) {
      final data = response['data'];
      if (data is List) {
        documents = data
            .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      documentsStatus = StatusRequest.success;
    } else {
      documentsStatus =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> loadActivationCode() async {
    activationStatus = StatusRequest.loading;
    update();

    final response = await _employeeData.getActivationCode(employeeId);

    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) {
        payload = payload['data'];
      }
      if (payload is Map<String, dynamic>) {
        _applyActivationPayload(payload);
      }
      activationStatus = StatusRequest.success;
    } else {
      activationStatus =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  /// Regenerates the activation code.
  ///
  /// For employees who are already `active`, this revokes their current
  /// device token (PRD §3.6 device-change flow) and resets status to
  /// `pending_activation` on the backend. Callers should confirm with the
  /// admin before invoking in that case.
  Future<bool> generateActivationCode() async {
    activationStatus = StatusRequest.loading;
    update();

    final response = await _employeeData.regenerateActivationCode(employeeId);

    if (response['status'] == StatusRequest.success) {
      dynamic payload = response['data'];
      if (payload is Map && payload['data'] is Map) {
        payload = payload['data'];
      }
      if (payload is Map<String, dynamic>) {
        _applyActivationPayload(payload);
        if (payload['device_revoked'] == true && employee != null) {
          // Backend flipped status back to pending_activation; refresh the
          // local employee so the UI matches.
          await loadEmployee();
          return true;
        }
      }
      Get.snackbar('done'.tr, 'code_regenerated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      activationStatus = StatusRequest.success;
      update();
      return true;
    }

    activationStatus =
        (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    Get.snackbar('error'.tr, 'error'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }

  void _applyActivationPayload(Map<String, dynamic> payload) {
    if (payload.containsKey('activation_code')) {
      activationCode = payload['activation_code'] as String?;
    }
    if (payload.containsKey('expires_at')) {
      final raw = payload['expires_at'];
      activationExpiresAt =
          raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
    }
    deviceBound = payload['device_bound'] == true;
    final device = payload['device'];
    if (device is Map<String, dynamic>) {
      deviceModel = device['device_model'] as String?;
      devicePlatform = device['platform'] as String?;
      final lastUsed = device['last_used_at'];
      deviceLastUsedAt =
          lastUsed is String ? DateTime.tryParse(lastUsed)?.toLocal() : null;
    } else {
      deviceModel = null;
      devicePlatform = null;
      deviceLastUsedAt = null;
    }
  }

  Future<void> copyCodeToClipboard() async {
    final code = activationCode;
    if (code == null || code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    Get.snackbar('done'.tr, 'code_copied'.tr,
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> shareCodeViaWhatsApp() async {
    final code = activationCode;
    final phone = employee?.phone;
    if (code == null || code.isEmpty) return;

    final message = 'activation_code_share_message'.trParams({
      'code': code,
      'employee_name': employee?.name ?? '',
    });

    final encoded = Uri.encodeComponent(message);
    final normalizedPhone = phone?.replaceAll(RegExp(r'[^0-9]'), '');

    final uri = normalizedPhone != null && normalizedPhone.isNotEmpty
        ? Uri.parse('https://wa.me/$normalizedPhone?text=$encoded')
        : Uri.parse('https://wa.me/?text=$encoded');

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      Get.snackbar('error'.tr, 'cannot_open_whatsapp'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Duration? get activationRemaining {
    final expires = activationExpiresAt;
    if (expires == null) return null;
    final delta = expires.difference(DateTime.now());
    return delta.isNegative ? Duration.zero : delta;
  }

  bool get hasActiveCode {
    final remaining = activationRemaining;
    return activationCode != null &&
        activationCode!.isNotEmpty &&
        remaining != null &&
        remaining > Duration.zero;
  }

  Future<void> deleteDocument(int docId) async {
    final response = await _documentData.deleteDocument(employeeId, docId);
    if (response['status'] == StatusRequest.success) {
      documents.removeWhere((d) => d.id == docId);
      Get.snackbar('done'.tr, 'document_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      update();
    }
  }

  bool get canManagePayroll {
    try {
      final auth = Get.find<AuthController>();
      return auth.user?.canManagePayroll ?? false;
    } catch (_) {
      return false;
    }
  }

  bool get canManageEmployees {
    try {
      final auth = Get.find<AuthController>();
      return auth.user?.canManageEmployees ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Updates the per-employee annual leave override.
  /// Pass [days] = null to clear it (employee inherits the company default).
  Future<void> updateAnnualLeaveDays(int? days) async {
    final response = await _employeeData.updateEmployee(employeeId, {
      'annual_leave_days': days,
    });

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'leave_settings_saved'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadEmployee();
    } else {
      Get.snackbar('error'.tr,
          (response['message'] as String?) ?? 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> addWarning({
    required String type,
    required String reason,
  }) async {
    warningStatus = StatusRequest.loading;
    update();

    final response = await _crud.postData(AppLinks.warningAdd, {
      'employee_id': employeeId,
      'type': type,
      'reason': reason,
    });

    if (response['status'] == StatusRequest.success) {
      warningStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'warning_added'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadEmployee();
    } else {
      warningStatus = StatusRequest.failure;
      Get.snackbar('error'.tr, 'warning_add_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  bool get canManageLeaves {
    try {
      final auth = Get.find<AuthController>();
      return auth.user?.canManageLeaves ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> convertAbsenceToLeave({
    required String date,
    required String type,
    required String reason,
  }) async {
    conversionStatus = StatusRequest.loading;
    update();

    final response = await _leaveData.convertAbsenceToLeave(
      employeeId: employeeId,
      date: date,
      type: type,
      reason: reason,
    );

    if (response['status'] == StatusRequest.success) {
      conversionStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'absence_converted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadAttendance();
      await loadEmployee();
    } else {
      conversionStatus = StatusRequest.failure;
      Get.snackbar('error'.tr, 'absence_conversion_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> addManualDeduction({
    required num amount,
    required String reason,
  }) async {
    adjustmentStatus = StatusRequest.loading;
    update();

    final response = await _payrollData.addManualDeduction(
      employeeId: employeeId,
      amount: amount,
      reason: reason,
    );

    if (response['status'] == StatusRequest.success) {
      adjustmentStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'deduction_added'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      adjustmentStatus = StatusRequest.failure;
      Get.snackbar('error'.tr, 'deduction_add_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> addManualBonus({
    required num amount,
    required String reason,
  }) async {
    adjustmentStatus = StatusRequest.loading;
    update();

    final response = await _payrollData.addManualBonus(
      employeeId: employeeId,
      amount: amount,
      reason: reason,
    );

    if (response['status'] == StatusRequest.success) {
      adjustmentStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'bonus_added'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      adjustmentStatus = StatusRequest.failure;
      Get.snackbar('error'.tr, 'bonus_add_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  Future<void> loadReviews() async {
    reviewStatus = StatusRequest.loading;
    update();

    final response = await _performanceData.getReviews(employeeId);

    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is List) {
        data = data['data'];
      }
      if (data is List) {
        reviews = data
            .map((e) =>
                PerformanceReviewModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      reviewStatus = StatusRequest.success;
    } else {
      reviewStatus =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<bool> addReview({
    required int rating,
    required String period,
    String? notes,
  }) async {
    reviewStatus = StatusRequest.loading;
    update();

    final response = await _performanceData.createReview({
      'employee_id': employeeId,
      'rating': rating,
      'period': period,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });

    if (response['status'] == StatusRequest.success) {
      reviewStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'review_added'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadReviews();
      update();
      return true;
    }

    reviewStatus = StatusRequest.failure;
    Get.snackbar('error'.tr, 'review_add_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }

  Future<void> deleteReview(int id) async {
    final response = await _performanceData.deleteReview(id);

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'review_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadReviews();
    } else {
      Get.snackbar('error'.tr, 'review_delete_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

