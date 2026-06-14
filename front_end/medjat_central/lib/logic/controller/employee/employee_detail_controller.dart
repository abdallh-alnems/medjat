import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/class/crud.dart';
import '../../../view/widget/pdf_preview_screen.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/id/app_links.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/data_source/remote/attendance_data/attendance_data.dart';
import '../../../data/data_source/remote/document_data/document_data.dart';
import '../../../data/data_source/remote/required_documents_data/required_documents_data.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';
import '../../../data/data_source/remote/performance_data/performance_data.dart';
import '../../../data/model/employee_model.dart';
import '../../../data/model/attendance_model.dart';
import '../../../data/model/document_model.dart';
import '../../../data/model/required_document_model.dart';
import '../../../data/model/warning_model.dart';
import '../../../data/model/suspension_model.dart';
import '../../../data/model/performance_review_model.dart';
import '../../../data/model/financial_summary_model.dart';
import '../../controller/auth/auth_controller.dart';

class EmployeeDetailController extends GetxController {
  final EmployeeData _employeeData = Get.find<EmployeeData>();
  final AttendanceData _attendanceData = Get.find<AttendanceData>();
  final DocumentData _documentData = Get.find<DocumentData>();
  final RequiredDocumentsData _requiredData = Get.find<RequiredDocumentsData>();
  final PayrollData _payrollData = Get.find<PayrollData>();
  final PerformanceData _performanceData = Get.find<PerformanceData>();
  final CRUD _crud = Get.find<CRUD>();

  StatusRequest status = StatusRequest.none;
  StatusRequest attendanceStatus = StatusRequest.none;
  StatusRequest documentsStatus = StatusRequest.none;
  StatusRequest documentCatalogStatus = StatusRequest.none;
  StatusRequest activationStatus = StatusRequest.none;
  StatusRequest adjustmentStatus = StatusRequest.none;
  StatusRequest warningStatus = StatusRequest.none;
  StatusRequest conversionStatus = StatusRequest.none;
  StatusRequest reviewStatus = StatusRequest.none;
  StatusRequest financialStatus = StatusRequest.none;
  StatusRequest suspensionStatus = StatusRequest.none;
  StatusRequest suspensionHistoryStatus = StatusRequest.none;

  EmployeeModel? employee;
  List<AttendanceRecordModel> attendanceRecords = [];
  Map<String, int> attendanceSummary = {
    'present': 0,
    'absent': 0,
    'late': 0,
    'leave': 0,
    'holiday': 0,
    'weekly_off': 0,
    'worked_minutes': 0,
    'overtime_minutes': 0,
    'late_minutes': 0,
  };
  // Attendance filter: either a whole month (use [attendanceMonth]) or a
  // custom range (use [attendanceFrom]/[attendanceTo]). When in range mode,
  // [attendanceMonth] is the calendar's anchor month for display.
  DateTime attendanceMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? attendanceFrom;
  DateTime? attendanceTo;
  bool get attendanceIsRange =>
      attendanceFrom != null && attendanceTo != null;

  // Attendance cycle start day (1-28). 1 = normal calendar month. Otherwise a
  // cycle runs from [cycleStartDay] of one month to [cycleStartDay-1] of the
  // next. The cycle is named after whichever month holds most of its days:
  // when it starts on day >= 17 the bulk of the days fall in the *next* month,
  // so it is labeled by the end month; when it starts on day <= 16 most days
  // are in the starting month, so it is labeled by the start month.
  int cycleStartDay = 1;
  bool _attendanceInitialized = false;
  bool _financialInitialized = false;

  /// True when the cycle should carry the name of its end month (most of its
  /// days fall there). With a 30/31-day month this is the case once the cycle
  /// starts on day 17 or later (days in the end month = cycleStartDay - 1 > 15).
  bool get cycleLabeledByEndMonth => cycleStartDay >= 17;

  /// Effective window start for the current selection (custom range or cycle).
  DateTime get periodFrom => attendanceIsRange
      ? attendanceFrom!
      : cycleWindowFrom(attendanceMonth);

  /// Effective window end (inclusive) for the current selection.
  DateTime get periodTo =>
      attendanceIsRange ? attendanceTo! : cycleWindowTo(attendanceMonth);

  /// Start date of the cycle whose label (majority) month is [labelMonth].
  DateTime cycleWindowFrom(DateTime labelMonth) {
    if (cycleStartDay <= 1) return DateTime(labelMonth.year, labelMonth.month);
    // End-labeled: cycle ends in [labelMonth], so it starts in the prior month.
    // Start-labeled: cycle starts in [labelMonth].
    final startMonthOffset = cycleLabeledByEndMonth ? -1 : 0;
    return DateTime(labelMonth.year, labelMonth.month + startMonthOffset, cycleStartDay);
  }

  /// Inclusive end date of the cycle whose label (majority) month is [labelMonth].
  DateTime cycleWindowTo(DateTime labelMonth) {
    if (cycleStartDay <= 1) return DateTime(labelMonth.year, labelMonth.month + 1, 0);
    // End-labeled: cycle ends in [labelMonth] on cycleStartDay-1.
    // Start-labeled: cycle ends in the month after [labelMonth] on cycleStartDay-1.
    final endMonthOffset = cycleLabeledByEndMonth ? 0 : 1;
    return DateTime(labelMonth.year, labelMonth.month + endMonthOffset, cycleStartDay - 1);
  }

  /// The label (majority) month of the cycle that contains today.
  DateTime currentCycleLabelMonth() => cycleLabelContaining(DateTime.now());

  /// Label month of the cycle that contains an arbitrary date.
  DateTime cycleLabelContaining(DateTime date) {
    if (cycleStartDay <= 1) return DateTime(date.year, date.month);
    final startMonthOffset = date.day >= cycleStartDay ? 0 : -1;
    final labelOffset = cycleLabeledByEndMonth ? 1 : 0;
    return DateTime(date.year, date.month + startMonthOffset + labelOffset);
  }

  /// Earliest label month the financial picker can land on — the cycle
  /// containing the employee's hire date. Null when no hire date is set.
  DateTime? minFinancialMonth() {
    final h = employee?.hireDate;
    if (h == null) return null;
    return cycleLabelContaining(h);
  }

  FinancialMonthSummary? financialCurrent;
  List<FinancialHistoryEntry> financialHistory = [];
  List<LoanSummary> financialLoans = [];
  EosbInfo? eosb;
  List<Allowance> allowances = [];
  List<SalaryChange> salaryHistory = [];
  DateTime financialMonth = DateTime(DateTime.now().year, DateTime.now().month);

  // Uploaded/known document records for the employee.
  List<DocumentModel> documents = [];
  // The full list of documents the company requires from THIS employee
  // (resolved across all scopes), shown with per-item status in the tab.
  List<RequiredDocumentModel> requiredDocuments = [];
  // The tenant's whole document-type catalog, loaded lazily for the
  // "request a document from this employee" picker.
  List<RequiredDocumentModel> documentCatalog = [];
  List<WarningModel> warnings = [];
  SuspensionModel? activeSuspension;
  List<SuspensionModel> suspensionHistory = [];
  bool get isSuspended =>
      activeSuspension != null || employee?.status == 'suspended';
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
  String? activationJoinLink;
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
    // Attendance loads once we know the employee's cycle start day (in
    // loadEmployee). Mark it loading up-front so the tab shows a spinner.
    attendanceStatus = StatusRequest.loading;
    loadEmployee();
    loadDocuments();
    loadReviews();
    // Financial month is anchored on the current cycle once we know the cycle
    // start day (in loadEmployee), so it is not loaded here.
  }

  String _formatMonth(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
        activeSuspension = data['active_suspension'] is Map<String, dynamic>
            ? SuspensionModel.fromJson(
                data['active_suspension'] as Map<String, dynamic>)
            : null;
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
        cycleStartDay = (data['cycle_start_day'] as num?)?.toInt() ?? 1;
      }
      status = StatusRequest.success;
      // First time we know the cycle: anchor on the current cycle and load.
      if (!_attendanceInitialized) {
        _attendanceInitialized = true;
        attendanceFrom = null;
        attendanceTo = null;
        attendanceMonth = currentCycleLabelMonth();
        unawaited(loadAttendanceMonth());
      }
      // Anchor the financial tab on the current cycle too.
      if (!_financialInitialized && canManagePayroll) {
        _financialInitialized = true;
        financialMonth = currentCycleLabelMonth();
        unawaited(loadFinancialMonth());
        unawaited(loadEosb());
        unawaited(loadAllowances());
      }
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> loadAttendanceMonth() async {
    attendanceStatus = StatusRequest.loading;
    update();

    // Always send an explicit window so custom cycles (e.g. 25→24) are honored.
    final response = await _employeeData.getAttendanceHistory(
      employeeId,
      from: _formatDate(periodFrom),
      to: _formatDate(periodTo),
    );

    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map<String, dynamic>) {
        if (data['records'] is List) {
          attendanceRecords = (data['records'] as List)
              .map((e) => AttendanceRecordModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        if (data['summary'] is Map<String, dynamic>) {
          final s = data['summary'] as Map<String, dynamic>;
          attendanceSummary = {
            'present': (s['present'] as num?)?.toInt() ?? 0,
            'absent': (s['absent'] as num?)?.toInt() ?? 0,
            'late': (s['late'] as num?)?.toInt() ?? 0,
            'leave': (s['leave'] as num?)?.toInt() ?? 0,
            'holiday': (s['holiday'] as num?)?.toInt() ?? 0,
            'weekly_off': (s['weekly_off'] as num?)?.toInt() ?? 0,
            'worked_minutes': (s['worked_minutes'] as num?)?.toInt() ?? 0,
            'overtime_minutes': (s['overtime_minutes'] as num?)?.toInt() ?? 0,
            'late_minutes': (s['late_minutes'] as num?)?.toInt() ?? 0,
          };
        }
      }
      attendanceStatus = StatusRequest.success;
    } else {
      attendanceStatus =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void changeAttendanceMonth(DateTime newMonth) {
    attendanceMonth = DateTime(newMonth.year, newMonth.month);
    attendanceFrom = null;
    attendanceTo = null;
    loadAttendanceMonth();
  }

  /// Switches to a custom date range. The calendar anchor is set to the start
  /// month so the calendar still renders meaningful colors for ranges that
  /// stay within a single month.
  void changeAttendanceRange(DateTime from, DateTime to) {
    attendanceFrom = DateTime(from.year, from.month, from.day);
    attendanceTo = DateTime(to.year, to.month, to.day);
    attendanceMonth = DateTime(from.year, from.month);
    loadAttendanceMonth();
  }

  Future<void> loadFinancialMonth() async {
    if (!canManagePayroll) return;
    financialStatus = StatusRequest.loading;
    update();

    final response = await _employeeData.getFinancialSummary(
      employeeId,
      _formatMonth(financialMonth),
    );

    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map<String, dynamic>) {
        if (data['current'] is Map<String, dynamic>) {
          financialCurrent = FinancialMonthSummary.fromJson(
            data['current'] as Map<String, dynamic>,
          );
        }
        if (data['history'] is List) {
          financialHistory = (data['history'] as List)
              .whereType<Map<String, dynamic>>()
              .map(FinancialHistoryEntry.fromJson)
              .toList();
        }
        if (data['loans'] is List) {
          financialLoans = (data['loans'] as List)
              .whereType<Map<String, dynamic>>()
              .map(LoanSummary.fromJson)
              .toList();
        } else {
          financialLoans = [];
        }
        if (data['salary_history'] is List) {
          salaryHistory = (data['salary_history'] as List)
              .whereType<Map<String, dynamic>>()
              .map(SalaryChange.fromJson)
              .toList();
        } else {
          salaryHistory = [];
        }
      }
      financialStatus = StatusRequest.success;
    } else {
      financialStatus =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void changeFinancialMonth(DateTime newMonth) {
    financialMonth = DateTime(newMonth.year, newMonth.month);
    loadFinancialMonth();
  }

  /// Loads accumulated End-of-Service Benefits for this employee from hire
  /// date to now. Silent on failure (the card simply stays hidden when EOSB
  /// is disabled or unavailable).
  Future<void> loadEosb() async {
    if (!canManagePayroll) return;
    final response = await _payrollData.getEosb(employeeId);
    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map<String, dynamic>) {
        eosb = EosbInfo.fromJson(data);
        update();
      }
    }
  }

  /// Loads the employee's recurring monthly allowances (every history row,
  /// active and inactive). The card uses [Allowance.isActive] to badge each.
  Future<void> loadAllowances() async {
    if (!canManagePayroll) return;
    final response = await _payrollData.listAllowances(employeeId);
    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) data = data['data'];
      if (data is Map<String, dynamic> && data['allowances'] is List) {
        allowances = (data['allowances'] as List)
            .whereType<Map<String, dynamic>>()
            .map(Allowance.fromJson)
            .toList();
        update();
      }
    }
  }

  Future<bool> saveAllowance({
    int? id,
    required String type,
    required num amount,
    required String startMonth,
    String? endMonth,
    String? label,
  }) async {
    adjustmentStatus = StatusRequest.loading;
    update();
    final response = id == null
        ? await _payrollData.createAllowance(
            employeeId: employeeId,
            type: type,
            amount: amount,
            startMonth: startMonth,
            endMonth: endMonth,
            label: label,
          )
        : await _payrollData.updateAllowance(
            id: id,
            type: type,
            amount: amount,
            startMonth: startMonth,
            endMonth: endMonth,
            label: label,
          );
    if (response['status'] == StatusRequest.success) {
      adjustmentStatus = StatusRequest.success;
      Get.snackbar('done'.tr,
          id == null ? 'allowance_added'.tr : 'allowance_updated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadAllowances();
      await loadFinancialMonth();
      return true;
    }
    adjustmentStatus = StatusRequest.failure;
    Get.snackbar('error'.tr, 'allowance_save_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }

  Future<bool> deleteAllowance(int id) async {
    adjustmentStatus = StatusRequest.loading;
    update();
    final response = await _payrollData.deleteAllowance(id);
    if (response['status'] == StatusRequest.success) {
      adjustmentStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'allowance_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadAllowances();
      await loadFinancialMonth();
      return true;
    }
    adjustmentStatus = StatusRequest.failure;
    Get.snackbar('error'.tr, 'allowance_delete_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }

  Future<void> loadDocuments() async {
    documentsStatus = StatusRequest.loading;
    update();

    final response = await _documentData.getDocuments(employeeId);

    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map) {
        if (data['documents'] is List) {
          documents = (data['documents'] as List)
              .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        if (data['required_documents'] is List) {
          requiredDocuments = (data['required_documents'] as List)
              .map((e) =>
                  RequiredDocumentModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } else if (data is List) {
        // Backwards-compatible with an older flat-list response shape.
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

  /// The uploaded record (if any) for a given required-document type.
  /// Rejected records are ignored so the type still reads as outstanding.
  DocumentModel? documentForRequired(int requiredDocumentId) {
    try {
      return documents.firstWhere((d) =>
          d.requiredDocumentId == requiredDocumentId && d.status != 'rejected');
    } catch (_) {
      return null;
    }
  }

  /// Count of required documents this employee has actually uploaded.
  int get uploadedRequiredCount => requiredDocuments
      .where((r) => documentForRequired(r.id)?.status == 'uploaded')
      .length;

  /// Loads the tenant's full document-type catalog (active types only),
  /// used to populate the request picker. Cheap and lazy.
  Future<void> loadDocumentCatalog() async {
    documentCatalogStatus = StatusRequest.loading;
    update();

    final response = await _requiredData.getRequired();

    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) {
        data = data['data'];
      }
      if (data is Map && data['required_documents'] is List) {
        documentCatalog = (data['required_documents'] as List)
            .map((e) => RequiredDocumentModel.fromJson(e as Map<String, dynamic>))
            .where((r) => r.isActive)
            .toList();
      } else if (data is List) {
        documentCatalog = data
            .map((e) => RequiredDocumentModel.fromJson(e as Map<String, dynamic>))
            .where((r) => r.isActive)
            .toList();
      }
      documentCatalogStatus = StatusRequest.success;
    } else {
      documentCatalogStatus =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  /// Catalog document types that are not yet required for this employee —
  /// i.e. the ones an admin can still request from this person.
  List<RequiredDocumentModel> get requestableDocuments {
    final alreadyRequired = requiredDocuments.map((r) => r.id).toSet();
    return documentCatalog
        .where((r) => !alreadyRequired.contains(r.id))
        .toList();
  }

  /// Requests a document type from this employee specifically. Reloads the
  /// employee's document list so the new requirement appears immediately.
  Future<bool> requestDocument(int requiredDocumentId) async {
    final response =
        await _documentData.requestDocument(employeeId, requiredDocumentId);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_requested'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadDocuments();
      return true;
    }
    Get.snackbar('error'.tr, 'request_document_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  /// Requests a custom document (hand-entered name/description) from this
  /// employee, independent of the company document catalog.
  Future<bool> requestCustomDocument({
    required String name,
    String? description,
  }) async {
    final response = await _documentData.requestCustomDocument(
      employeeId,
      name: name,
      description: description,
    );
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_requested'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadDocuments();
      return true;
    }
    Get.snackbar('error'.tr, 'request_document_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  bool get canManageDocuments {
    try {
      final auth = Get.find<AuthController>();
      return auth.user?.canManageDocuments ?? false;
    } catch (_) {
      return false;
    }
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
  /// For active employees this also revokes the existing device token —
  /// caller should confirm with the admin before invoking in that case.
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
          // Clear the loading state before reloading the profile, otherwise it
          // stays stuck on `loading` (loadEmployee only touches `status`) and
          // the regenerate/reset buttons remain disabled after a device reset.
          activationStatus = StatusRequest.success;
          await loadEmployee();
          return true;
        }
      }
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
    if (payload.containsKey('join_link')) {
      activationJoinLink = payload['join_link'] as String?;
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

  Future<void> copyJoinLinkToClipboard() async {
    final link = activationJoinLink;
    if (link == null || link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link));
    Get.snackbar('done'.tr, 'link_copied'.tr,
        snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> shareCodeViaWhatsApp() async {
    final code = activationCode;
    final phone = employee?.phone;
    if (code == null || code.isEmpty) return;

    final message = 'activation_code_share_message'.trParams({
      'code': code,
      'employee_name': employee?.name ?? '',
      'phone': phone ?? '',
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

  Future<void> verifyDocument(int docId) async {
    final response = await _documentData.verifyDocument(docId);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_verified'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadDocuments();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> rejectDocument(int docId, String reason) async {
    final response = await _documentData.rejectDocument(docId, reason);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'document_rejected'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadDocuments();
    } else {
      Get.snackbar('error'.tr, 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // Id of the document currently being downloaded (for a spinner / disabling).
  int? openingDocId;

  /// Downloads the document file via an authenticated request and opens it in
  /// the device's default viewer (image/PDF) so the admin can review it.
  Future<void> openDocument(int docId,
      {String? mimeType, String? originalName}) async {
    openingDocId = docId;
    update();
    try {
      final response = await _documentData.downloadFile(docId);
      final bytes = response['bytes'];

      if (response['status'] == StatusRequest.offline) {
        Get.snackbar('error'.tr, 'offline_error'.tr,
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      if (response['status'] != StatusRequest.success || bytes is! List<int>) {
        final code = response['statusCode'];
        final err = response['error'];
        Get.snackbar(
            'error'.tr,
            '${'document_open_failed'.tr}'
            '${code != null ? ' ($code)' : ''}'
            '${err != null ? '\n$err' : ''}',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 6));
        return;
      }

      final data = Uint8List.fromList(bytes);
      final lowerName = (originalName ?? '').toLowerCase();
      final isPdf = (mimeType?.contains('pdf') ?? false) ||
          lowerName.endsWith('.pdf');

      if (!isPdf) {
        // Images: preview in-app from memory (no temp file, no native plugin).
        unawaited(Get.dialog<void>(
          _ImagePreviewDialog(bytes: data),
          barrierColor: Colors.black87,
        ));
        return;
      }

      // PDFs: preview in-app (no external viewer).
      unawaited(
          Get.to<void>(() => PdfPreviewScreen(bytes: data, title: originalName)));
    } catch (e) {
      Get.snackbar('error'.tr, '${'document_open_failed'.tr}: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      openingDocId = null;
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

  /// Updates one or more editable fields on the employee profile.
  /// Pass a string value for text fields; pass `''` (empty string) to clear
  /// optional/date fields back to NULL.
  Future<bool> updateEmployeeInfo(Map<String, dynamic> changes) async {
    if (changes.isEmpty) return true;
    final response = await _employeeData.updateEmployee(employeeId, changes);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'saved_successfully'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadEmployee();
      return true;
    }
    Get.snackbar('error'.tr,
        (response['message'] as String?) ?? 'error'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

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

  /// Suspend the employee from work. [payMode] is `unpaid`, `partial`, or
  /// `full`; [payPercentage] is required (0–100) only for `partial`. Pass a
  /// null/empty [endDate] for an open-ended suspension. Returns true on success.
  Future<bool> suspendEmployee({
    required String reason,
    required String payMode,
    double? payPercentage,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    suspensionStatus = StatusRequest.loading;
    update();

    final response = await _employeeData.suspendEmployee(
      employeeId,
      reason: reason,
      payMode: payMode,
      payPercentage: payMode == 'partial' ? payPercentage : null,
      startDate: _formatDate(startDate),
      endDate: endDate != null ? _formatDate(endDate) : null,
    );

    if (response['status'] == StatusRequest.success) {
      suspensionStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'suspension_done'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadEmployee();
      update();
      return true;
    }
    suspensionStatus = StatusRequest.failure;
    Get.snackbar('error'.tr, 'suspension_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }

  /// Lift the active suspension and restore the employee's prior status.
  Future<bool> endSuspension({String? endNote}) async {
    suspensionStatus = StatusRequest.loading;
    update();

    final response =
        await _employeeData.endSuspension(employeeId, endNote: endNote);

    if (response['status'] == StatusRequest.success) {
      suspensionStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'suspension_ended'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadEmployee();
      update();
      return true;
    }
    suspensionStatus = StatusRequest.failure;
    Get.snackbar('error'.tr, 'suspension_end_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }

  /// Load the full suspension history (newest first) for the disciplinary tab.
  Future<void> loadSuspensionHistory() async {
    suspensionHistoryStatus = StatusRequest.loading;
    update();

    final response = await _employeeData.getSuspensions(employeeId);
    if (response['status'] == StatusRequest.success) {
      dynamic data = response['data'];
      if (data is Map && data['data'] is Map) data = data['data'];
      if (data is Map<String, dynamic>) {
        if (data['suspensions'] is List) {
          suspensionHistory = (data['suspensions'] as List)
              .whereType<Map<String, dynamic>>()
              .map(SuspensionModel.fromJson)
              .toList();
        }
        activeSuspension = data['active'] is Map<String, dynamic>
            ? SuspensionModel.fromJson(data['active'] as Map<String, dynamic>)
            : activeSuspension;
      }
      suspensionHistoryStatus = StatusRequest.success;
    } else {
      suspensionHistoryStatus =
          (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  Future<void> deleteWarning(int id) async {
    final response = await _crud.postData(AppLinks.warningDelete, {'id': id});

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'warning_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadEmployee();
    } else {
      Get.snackbar('error'.tr, 'warning_delete_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  bool get canManageLeaves {
    try {
      final auth = Get.find<AuthController>();
      return auth.user?.canManageLeaves ?? false;
    } catch (_) {
      return false;
    }
  }

  bool get canManageAttendance {
    try {
      final auth = Get.find<AuthController>();
      return auth.user?.canManageAttendance ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Unified day-status editor: sets a single calendar day to
  /// `present` / `absent` / `leave`. Pass times only for `present`, and
  /// [leaveType] only for `leave`. Reloads attendance + employee (so the
  /// leave balance refreshes) on success.
  Future<bool> setDayStatus({
    required String date,
    required String status,
    String? checkInTime,
    String? checkOutTime,
    String? leaveType,
    String? reason,
    String? deductionMode,
    num? deductionValue,
  }) async {
    conversionStatus = StatusRequest.loading;
    update();

    final response = await _attendanceData.setDayStatus(
      employeeId: employeeId,
      date: date,
      status: status,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      leaveType: leaveType,
      reason: reason,
      deductionMode: deductionMode,
      deductionValue: deductionValue,
    );

    if (response['status'] == StatusRequest.success) {
      conversionStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'day_status_changed'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadAttendanceMonth();
      await loadEmployee();
      update();
      return true;
    }

    conversionStatus = StatusRequest.failure;
    Get.snackbar('error'.tr,
        (response['message'] as String?) ?? 'day_status_change_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
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
      await loadFinancialMonth();
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
      await loadFinancialMonth();
    } else {
      adjustmentStatus = StatusRequest.failure;
      Get.snackbar('error'.tr, 'bonus_add_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  /// Edits an existing manual deduction or bonus line. [isDeduction] picks
  /// which endpoint to hit; both expect the manual_* row id from the summary.
  Future<bool> updateManualAdjustment({
    required int id,
    required bool isDeduction,
    required num amount,
    required String reason,
  }) async {
    adjustmentStatus = StatusRequest.loading;
    update();
    final response = isDeduction
        ? await _payrollData.updateManualDeduction(
            id: id, amount: amount, reason: reason)
        : await _payrollData.updateManualBonus(
            id: id, amount: amount, reason: reason);
    if (response['status'] == StatusRequest.success) {
      adjustmentStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'adjustment_updated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadFinancialMonth();
      return true;
    }
    adjustmentStatus = StatusRequest.failure;
    Get.snackbar('error'.tr, 'adjustment_update_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }

  /// Edit the amount of, remove, or restore any computed (non-manual) payroll
  /// line — absence, late, loan, insurance, tax, overtime… — for the current
  /// financial month. [action] is 'set' (with [amount]), 'waive' or 'clear'.
  Future<bool> overrideAdjustmentLine({
    required FinancialAdjustment line,
    required bool isDeduction,
    required String action,
    num? amount,
    String? reason,
  }) async {
    adjustmentStatus = StatusRequest.loading;
    update();
    final response = await _payrollData.overrideLine(
      employeeId: employeeId,
      month: _formatMonth(financialMonth),
      kind: isDeduction ? 'deduction' : 'bonus',
      type: line.type,
      date: line.date,
      description: line.description,
      action: action,
      amount: amount,
      reason: reason,
    );
    if (response['status'] == StatusRequest.success) {
      adjustmentStatus = StatusRequest.success;
      Get.snackbar(
        'done'.tr,
        action == 'clear'
            ? 'adjustment_override_cleared'.tr
            : (action == 'waive'
                ? 'adjustment_deleted'.tr
                : 'adjustment_updated'.tr),
        snackPosition: SnackPosition.BOTTOM,
      );
      await loadFinancialMonth();
      return true;
    }
    adjustmentStatus = StatusRequest.failure;
    Get.snackbar('error'.tr, 'adjustment_update_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }

  /// Approve the current month's payroll slip (draft → approved). No-op if
  /// the slip doesn't exist yet (admin must run the monthly generate first).
  Future<bool> approveCurrentSlip() async {
    final id = financialCurrent?.payrollId;
    if (id == null) return false;
    adjustmentStatus = StatusRequest.loading;
    update();
    final response = await _payrollData.approveSlip(id);
    if (response['status'] == StatusRequest.success) {
      adjustmentStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'payroll_approved'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadFinancialMonth();
      return true;
    }
    adjustmentStatus = StatusRequest.failure;
    Get.snackbar('error'.tr, 'payroll_approve_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }

  /// Mark the current month's slip as paid (approved → paid).
  Future<bool> markCurrentSlipPaid({String? paidAt}) async {
    final id = financialCurrent?.payrollId;
    if (id == null) return false;
    adjustmentStatus = StatusRequest.loading;
    update();
    final response = await _payrollData.markSlipPaid(id, paidAt: paidAt);
    if (response['status'] == StatusRequest.success) {
      adjustmentStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'payroll_marked_paid'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadFinancialMonth();
      return true;
    }
    adjustmentStatus = StatusRequest.failure;
    Get.snackbar('error'.tr, 'payroll_mark_paid_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }

  /// Step the current slip one state back (paid → approved, or approved →
  /// draft) so corrections can be made.
  Future<bool> revertCurrentSlip() async {
    final id = financialCurrent?.payrollId;
    if (id == null) return false;
    adjustmentStatus = StatusRequest.loading;
    update();
    final response = await _payrollData.revertSlip(id);
    if (response['status'] == StatusRequest.success) {
      adjustmentStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'payroll_reverted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadFinancialMonth();
      return true;
    }
    adjustmentStatus = StatusRequest.failure;
    Get.snackbar('error'.tr, 'payroll_revert_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
  }

  /// Downloads the payslip PDF for the currently-selected financial month.
  /// Returns the local file path on success (so the UI can open/share it),
  /// or null on failure. Toasts both outcomes.
  Future<String?> downloadPayslipPdf() async {
    Get.snackbar('payslip_downloading'.tr, '',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2));
    final monthStr =
        '${financialMonth.year}-${financialMonth.month.toString().padLeft(2, '0')}';
    final path =
        await _payrollData.downloadPayslipPdf(employeeId, monthStr);
    if (path == null) {
      Get.snackbar('error'.tr, 'payslip_download_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return null;
    }
    return path;
  }

  Future<bool> deleteManualAdjustment({
    required int id,
    required bool isDeduction,
  }) async {
    adjustmentStatus = StatusRequest.loading;
    update();
    final response = isDeduction
        ? await _payrollData.deleteManualDeduction(id)
        : await _payrollData.deleteManualBonus(id);
    if (response['status'] == StatusRequest.success) {
      adjustmentStatus = StatusRequest.success;
      Get.snackbar('done'.tr, 'adjustment_deleted'.tr,
          snackPosition: SnackPosition.BOTTOM);
      await loadFinancialMonth();
      return true;
    }
    adjustmentStatus = StatusRequest.failure;
    Get.snackbar('error'.tr, 'adjustment_delete_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    update();
    return false;
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

/// Fullscreen, zoomable in-app preview for an image document (no temp file or
/// native viewer needed — renders the downloaded bytes directly).
class _ImagePreviewDialog extends StatelessWidget {
  final Uint8List bytes;
  const _ImagePreviewDialog({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
          Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Get.back<void>(),
            ),
          ),
        ],
      ),
    );
  }
}
