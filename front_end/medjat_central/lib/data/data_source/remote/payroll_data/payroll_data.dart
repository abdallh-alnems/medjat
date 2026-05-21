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

  Future<Map<String, dynamic>> approvePayroll(int id) async {
    return await _crud.postData(AppLinks.payrollApprove(id), {});
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

  Future<Map<String, dynamic>> getBankFilePreview(String month, {int? branchId}) async {
    final params = <String, dynamic>{'month': month};
    if (branchId != null) params['branch_id'] = branchId;
    return await _crud.getData(AppLinks.payrollBankPreview, queryParameters: params);
  }

  Future<String?> downloadBankFile(String month, {int? branchId}) async {
    try {
      final uri = Uri.parse(AppLinks.payrollBankFile);
      final params = <String, String>{'month': month};
      if (branchId != null) params['branch_id'] = branchId.toString();

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
