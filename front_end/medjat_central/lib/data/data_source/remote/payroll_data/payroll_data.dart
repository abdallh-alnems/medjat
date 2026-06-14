import 'dart:io';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';
import '../../../../core/services/token_storage_service.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PayrollData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getPayrolls({int? branchId}) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.payroll, queryParameters: params);
  }

  Future<Map<String, dynamic>> getPayrollMonth(int month, int year, {int? branchId}) async {
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final params = <String, dynamic>{'month': monthStr};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.payroll, queryParameters: params);
  }

  Future<Map<String, dynamic>> getPayrollLive(int month, int year, {int? branchId}) async {
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final params = <String, dynamic>{'month': monthStr};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.payrollLive, queryParameters: params);
  }

  Future<Map<String, dynamic>> approvePayroll(int id) async {
    return await _crud.postData(AppLinks.payrollApprove(id), {});
  }

  Future<Map<String, dynamic>> approveBulk(List<int> ids) async {
    return await _crud.postData(AppLinks.payrollApproveBulk, {'ids': ids});
  }

  /// `paidAt` is "YYYY-MM-DD". Pass null to default to today server-side.
  Future<Map<String, dynamic>> markPaid(List<int> ids, {String? paidAt}) async {
    final body = <String, dynamic>{'ids': ids};
    if (paidAt != null) body['paid_at'] = paidAt;
    return await _crud.postData(AppLinks.payrollMarkPaid, body);
  }

  /// Drive one employee's slip for `month` (YYYY-MM) all the way to paid,
  /// creating + approving it as needed. `paidAt` is "YYYY-MM-DD"; null defaults
  /// to today server-side.
  Future<Map<String, dynamic>> disburseEmployee(int employeeId, String month,
      {String? paidAt}) async {
    final body = <String, dynamic>{'employee_id': employeeId, 'month': month};
    if (paidAt != null) body['paid_at'] = paidAt;
    return await _crud.postData(AppLinks.payrollDisburse, body);
  }

  /// Disburse every active employee's salary for `month` (YYYY-MM), optionally
  /// scoped to one branch. Slips already paid are left untouched.
  Future<Map<String, dynamic>> disburseAll(String month, {int? branchId}) async {
    final body = <String, dynamic>{'month': month};
    if (branchId != null) body['branch_id'] = branchId;
    return await _crud.postData(AppLinks.payrollDisburseAll, body);
  }

  /// Generate (or refresh) draft slips for every active employee for `month`
  /// (YYYY-MM). Branch-scoped when `branchId` is provided.
  Future<Map<String, dynamic>> generatePayroll(String month, {int? branchId}) async {
    final body = <String, dynamic>{'month': month};
    if (branchId != null) body['branch_id'] = branchId;
    return await _crud.postData(AppLinks.payrollGenerate, body);
  }

  Future<Map<String, dynamic>> getAuditLog({int page = 1, int limit = 50}) async {
    return await _crud.getData(
      AppLinks.payrollAuditLog,
      queryParameters: {'page': page, 'limit': limit},
    );
  }

  Future<Map<String, dynamic>> addManualDeduction({
    required int employeeId,
    required num amount,
    required String reason,
  }) async {
    return await _crud.postData(AppLinks.deductionManualAdd, {
      'employee_id': employeeId,
      'amount': amount,
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>> addManualBonus({
    required int employeeId,
    required num amount,
    required String reason,
  }) async {
    return await _crud.postData(AppLinks.bonusManualAdd, {
      'employee_id': employeeId,
      'amount': amount,
      'reason': reason,
    });
  }

  /// Apply a manual bonus/deduction to every employee in a scope
  /// (branch/shift/category) at once. [kind] is 'bonus' or 'deduction';
  /// [scopeType] is 'branch', 'shift', or 'category'.
  ///
  /// Routed through the tracked bulk-adjustments endpoint so these scope-screen
  /// shortcuts produce the same managed batches as the dedicated screen.
  Future<Map<String, dynamic>> bulkAdjust({
    required String kind,
    required String scopeType,
    required int scopeId,
    required num amount,
    required String reason,
    String amountType = 'fixed', // 'fixed' | 'percent'
  }) async {
    return await _crud.postData(AppLinks.bulkAdjustmentCreate, {
      'kind': kind,
      'scope_type': scopeType,
      'scope_id': scopeId,
      'amount': amount,
      'amount_type': amountType,
      'reason': reason,
    });
  }

  /// Edit the amount of, remove, or restore any computed payroll line
  /// (absence/late/loan/insurance/tax/overtime…) for one employee+month.
  /// [action] is 'set' (with [amount]), 'waive', or 'clear'.
  Future<Map<String, dynamic>> overrideLine({
    required int employeeId,
    required String month,
    required String kind, // 'deduction' | 'bonus'
    required String type,
    String? date,
    required String description,
    required String action, // 'set' | 'waive' | 'clear'
    num? amount,
    String? reason,
  }) async {
    return await _crud.postData(AppLinks.payrollOverrideLine, {
      'employee_id': employeeId,
      'month': month,
      'line_kind': kind,
      'line_type': type,
      'line_date': ?date,
      'line_desc': description,
      'action': action,
      'amount': ?amount,
      'reason': ?reason,
    });
  }

  Future<Map<String, dynamic>> getEosb(int employeeId) async {
    return await _crud.getData(AppLinks.payrollEosb(employeeId));
  }

  // ── Recurring monthly allowances ─────────────────────────
  Future<Map<String, dynamic>> listAllowances(int employeeId) async {
    return await _crud.getData(AppLinks.allowancesList(employeeId));
  }

  Future<Map<String, dynamic>> createAllowance({
    required int employeeId,
    required String type,
    required num amount,
    required String startMonth,
    String? endMonth,
    String? label,
  }) async {
    return await _crud.postData(AppLinks.allowanceCreate, {
      'employee_id': employeeId,
      'type': type,
      'amount': amount,
      'start_month': startMonth,
      'end_month': ?endMonth,
      'label': ?label,
    });
  }

  Future<Map<String, dynamic>> updateAllowance({
    required int id,
    required String type,
    required num amount,
    required String startMonth,
    String? endMonth,
    String? label,
  }) async {
    return await _crud.postData(AppLinks.allowanceUpdate, {
      'id': id,
      'type': type,
      'amount': amount,
      'start_month': startMonth,
      'end_month': ?endMonth,
      'label': ?label,
    });
  }

  Future<Map<String, dynamic>> deleteAllowance(int id) async {
    return await _crud.postData(AppLinks.allowanceDelete, {'id': id});
  }

  /// Per-slip approval actions wired to the financial tab. Each one POSTs
  /// `payroll_id` in the request body — that's the contract the existing
  /// approve.php/mark_paid.php/revert.php endpoints expect.
  Future<Map<String, dynamic>> approveSlip(int payrollId) async {
    return await _crud
        .postData(AppLinks.payrollSlipApprove, {'payroll_id': payrollId});
  }

  Future<Map<String, dynamic>> markSlipPaid(int payrollId,
      {String? paidAt}) async {
    final body = <String, dynamic>{'payroll_id': payrollId};
    if (paidAt != null) body['paid_at'] = paidAt;
    return await _crud.postData(AppLinks.payrollSlipMarkPaid, body);
  }

  Future<Map<String, dynamic>> revertSlip(int payrollId) async {
    return await _crud
        .postData(AppLinks.payrollSlipRevert, {'payroll_id': payrollId});
  }

  Future<Map<String, dynamic>> updateManualDeduction({
    required int id,
    required num amount,
    required String reason,
  }) async {
    return await _crud.postData(AppLinks.deductionManualUpdate, {
      'id': id,
      'amount': amount,
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>> deleteManualDeduction(int id) async {
    return await _crud.postData(AppLinks.deductionManualDelete, {'id': id});
  }

  Future<Map<String, dynamic>> updateManualBonus({
    required int id,
    required num amount,
    required String reason,
  }) async {
    return await _crud.postData(AppLinks.bonusManualUpdate, {
      'id': id,
      'amount': amount,
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>> deleteManualBonus(int id) async {
    return await _crud.postData(AppLinks.bonusManualDelete, {'id': id});
  }

  Future<Map<String, dynamic>> getBankFilePreview(String month, {int? branchId}) async {
    final params = <String, dynamic>{'month': month};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.payrollBankPreview, queryParameters: params);
  }

  /// Downloads the employee's monthly payslip PDF to a temp file and returns
  /// its local path (or null on failure). Mirrors [downloadBankFile] for auth
  /// headers so it works with the existing API security model.
  Future<String?> downloadPayslipPdf(int employeeId, String month) async {
    try {
      final uri = Uri.parse(AppLinks.payrollSlipPdf(employeeId, month));
      final params = Map<String, String>.from(uri.queryParameters);

      final headers = <String, String>{};
      final securityUser = dotenv.env['SECURITY_USER'] ?? '';
      final securityKey = dotenv.env['SECURITY_KEY'] ?? '';
      headers['Authorization'] =
          'Basic ${base64Encode(utf8.encode('$securityUser:$securityKey'))}';
      headers['Accept'] = 'application/pdf';

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final idToken = await user.getIdToken();
        if (idToken != null) {
          headers['X-Firebase-Token'] = idToken;
          params['token'] = idToken;
        }
      }

      final userData = await TokenStorageService.getUserData();
      if (userData != null) {
        try {
          final json = jsonDecode(userData);
          final tenantId = json['tenant_id'];
          if (tenantId != null && tenantId != 0) {
            headers['X-Tenant-Id'] = tenantId.toString();
            params['tenant_id'] = tenantId.toString();
          }
        } catch (_) {}
      }

      final response = await http
          .get(uri.replace(queryParameters: params), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dir = Directory.systemTemp;
        final filename = 'payslip_${employeeId}_$month.pdf';
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> downloadBankFile(String month, {int? branchId, String? exporterKey}) async {
    try {
      final uri = Uri.parse(AppLinks.payrollBankFile);
      final params = <String, String>{'month': month};
      if (branchId != null) params['branch_id'] = branchId.toString();
      if (exporterKey != null) params['exporter'] = exporterKey;

      final headers = <String, String>{};
      final securityUser = dotenv.env['SECURITY_USER'] ?? '';
      final securityKey = dotenv.env['SECURITY_KEY'] ?? '';
      headers['Authorization'] =
          'Basic ${base64Encode(utf8.encode('$securityUser:$securityKey'))}';
      headers['Accept'] = 'text/csv';

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final idToken = await user.getIdToken();
        if (idToken != null) {
          headers['X-Firebase-Token'] = idToken;
          params['token'] = idToken;
        }
      }

      final userData = await TokenStorageService.getUserData();
      if (userData != null) {
        try {
          final json = jsonDecode(userData);
          final tenantId = json['tenant_id'];
          if (tenantId != null && tenantId != 0) {
            headers['X-Tenant-Id'] = tenantId.toString();
            params['tenant_id'] = tenantId.toString();
          }
        } catch (_) {}
      }

      final response = await http
          .get(uri.replace(queryParameters: params), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dir = Directory.systemTemp;
        final filename = 'payroll_bank_$month.csv';
        final file = File('${dir.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
