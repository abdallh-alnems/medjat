import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class BreakData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getMyBreaks({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    return await _crud.getData(AppLinks.breakMyList, queryParameters: params);
  }

  Future<Map<String, dynamic>> getBreaks({
    int? branchId,
    int? categoryId,
    String? search,
    String? status,
    String? from,
    String? to,
  }) async {
    final params = <String, dynamic>{};
    if (branchId != null) params['branch_id'] = branchId;
    if (categoryId != null) params['category_id'] = categoryId;
    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (status != null) params['status'] = status;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    return await _crud.getData(AppLinks.breakList, queryParameters: params);
  }

  Future<Map<String, dynamic>> createBreak(Map<String, dynamic> data) async {
    // Manager-created permission on behalf of a chosen employee (admin auth).
    return await _crud.postData(AppLinks.breakCreateFor, data);
  }

  Future<Map<String, dynamic>> cancelBreak(int breakId) async {
    return await _crud.postData(AppLinks.breakCancel, {'break_id': breakId});
  }

  Future<Map<String, dynamic>> approveBreak(
    int breakId, {
    String? note,
    bool? deductFromSalary,
  }) async {
    return await _crud.postData(AppLinks.breakApprove, {
      'break_id': breakId,
      if (note != null) 'note': note,
      if (deductFromSalary != null) 'deduct_from_salary': deductFromSalary ? 1 : 0,
    });
  }

  Future<Map<String, dynamic>> rejectBreak(int breakId, {String? reason}) async {
    return await _crud.postData(AppLinks.breakReject, {
      'break_id': breakId,
      if (reason != null) 'rejection_reason': reason,
    });
  }

  Future<Map<String, dynamic>> postponeBreak(
    int breakId, {
    String? note,
    String? suggestedDate,
    String? suggestedStartTime,
    String? suggestedEndTime,
  }) async {
    return await _crud.postData(AppLinks.breakPostpone, {
      'break_id': breakId,
      if (note != null) 'note': note,
      if (suggestedDate != null) 'suggested_date': suggestedDate,
      if (suggestedStartTime != null) 'suggested_start_time': suggestedStartTime,
      if (suggestedEndTime != null) 'suggested_end_time': suggestedEndTime,
    });
  }
}
