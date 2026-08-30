import 'package:get/get.dart';
import '../../../../core/class/crud.dart';
import '../../../../core/constant/id/app_links.dart';

class BulkAdjustmentData {
  final CRUD _crud = Get.find<CRUD>();

  Future<Map<String, dynamic>> getList() async {
    return await _crud.getData(AppLinks.bulkAdjustmentList);
  }

  Future<Map<String, dynamic>> getOne(int id) async {
    return await _crud.getData(
      AppLinks.bulkAdjustmentGet,
      queryParameters: {'id': id},
    );
  }

  /// scopeId is required for branch/category/employee; omit (null) for 'all'.
  /// month is 'YYYY-MM' (defaults to current server month when null). When
  /// [dryRun] is true the server returns preview counts/warnings and writes
  /// nothing.
  Future<Map<String, dynamic>> create({
    required String kind,
    required String scopeType,
    int? scopeId,
    required num amount,
    required String amountType,
    String reason = '',
    String? month,
    bool dryRun = false,
  }) async {
    final body = <String, dynamic>{
      'kind': kind,
      'scope_type': scopeType,
      'amount': amount,
      'amount_type': amountType,
      'reason': reason,
      'dry_run': dryRun,
    };
    if (scopeId != null) body['scope_id'] = scopeId;
    if (month != null) body['month'] = month;
    return await _crud.postData(AppLinks.bulkAdjustmentCreate, body);
  }

  Future<Map<String, dynamic>> update({
    required int id,
    required num amount,
    required String amountType,
    String reason = '',
  }) async {
    return await _crud.postData(AppLinks.bulkAdjustmentUpdate, {
      'id': id,
      'amount': amount,
      'amount_type': amountType,
      'reason': reason,
    });
  }

  Future<Map<String, dynamic>> delete(int id) async {
    return await _crud.postData(AppLinks.bulkAdjustmentDelete, {'id': id});
  }

  Future<Map<String, dynamic>> removeMember(int id, int rowId) async {
    return await _crud.postData(AppLinks.bulkAdjustmentRemoveMember, {
      'id': id,
      'row_id': rowId,
    });
  }
}
