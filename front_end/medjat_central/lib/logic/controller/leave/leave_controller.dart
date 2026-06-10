import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/leave_data/leave_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/model/leave_model.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/model/employee_category_model.dart';

class LeaveController extends GetxController {
  final LeaveData _leaveData = Get.find<LeaveData>();
  final BranchData _branchData = Get.find<BranchData>();
  final CategoryData _categoryData = Get.find<CategoryData>();

  StatusRequest status = StatusRequest.none;
  List<LeaveModel> leaves = [];
  String? statusFilter;

  /// 0 = current requests, 1 = ended & rejected archive.
  int requestsTab = 0;
  void setRequestsTab(int index) {
    if (requestsTab == index) return;
    requestsTab = index;
    update();
  }

  // ── Filters ───────────────────────────────────────────
  List<BranchModel> branches = [];
  List<EmployeeCategoryModel> categories = [];
  int? branchFilter;
  int? categoryFilter;
  String searchQuery = '';

  // Branch & category are applied server-side (reload); search stays local.
  void setBranchFilter(int? id) {
    branchFilter = id;
    loadLeaves();
  }

  void setCategoryFilter(int? id) {
    categoryFilter = id;
    loadLeaves();
  }

  void setSearchQuery(String q) {
    searchQuery = q;
    update();
  }

  void clearFilters() {
    branchFilter = null;
    categoryFilter = null;
    searchQuery = '';
    loadLeaves();
  }

  bool get hasActiveFilters =>
      branchFilter != null || categoryFilter != null || searchQuery.trim().isNotEmpty;

  /// Branch & category are already applied by the server; only the live
  /// employee-name search is filtered locally for instant feedback.
  List<LeaveModel> get filteredLeaves {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return leaves;
    return leaves
        .where((l) => (l.employeeName ?? '').toLowerCase().contains(q))
        .toList();
  }

  Map<String, dynamic>? balanceInfo;
  bool balanceLoading = false;

  @override
  void onInit() {
    super.onInit();
    loadLeaves();
    loadFilterData();
  }

  Future<void> loadFilterData() async {
    try {
      final bRes = await _branchData.getBranches();
      if (bRes['status'] == StatusRequest.success) {
        branches = _extractBranches(bRes['data']);
      }
      final cRes = await _categoryData.getCategories();
      if (cRes['status'] == StatusRequest.success) {
        categories = _extractCategories(cRes['data']);
      }
      update();
    } catch (_) {}
  }

  List<BranchModel> _extractBranches(dynamic data) {
    if (data is Map && data['data'] is Map) data = data['data'];
    if (data is Map && data['branches'] is List) {
      data = data['branches'];
    }
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(BranchModel.fromJson)
          .toList();
    }
    return [];
  }

  List<EmployeeCategoryModel> _extractCategories(dynamic body) {
    if (body is Map && body['data'] is Map) body = body['data'];
    if (body is Map && body['categories'] is List) {
      body = body['categories'];
    }
    if (body is List) {
      return body
          .whereType<Map<String, dynamic>>()
          .map(EmployeeCategoryModel.fromJson)
          .toList();
    }
    return [];
  }

  Future<void> loadLeaves() async {
    status = StatusRequest.loading;
    update();

    final response = await _leaveData.getLeaves(
      status: statusFilter,
      branchId: branchFilter,
      categoryId: categoryFilter,
    );

    if (response['status'] == StatusRequest.success) {
      leaves = _extractItems(response['data']);
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  List<LeaveModel> _extractItems(dynamic raw) {
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
    final list = items
        .whereType<Map<String, dynamic>>()
        .map(LeaveModel.fromJson)
        .toList();
    // Newest request first (by request date, then id as tie-breaker).
    list.sort((a, b) {
      final ad = a.createdAt;
      final bd = b.createdAt;
      if (ad != null && bd != null) {
        final c = bd.compareTo(ad);
        if (c != 0) return c;
      } else if (ad == null && bd != null) {
        return 1;
      } else if (ad != null && bd == null) {
        return -1;
      }
      return b.id.compareTo(a.id);
    });
    return list;
  }

  void filterByStatus(String? status) {
    statusFilter = status;
    loadLeaves();
  }

  Future<void> loadBalance(int employeeId, {int? year}) async {
    balanceLoading = true;
    balanceInfo = null;
    update();
    try {
      final response =
          await _leaveData.leaveBalance(employeeId, year: year);
      if (response['status'] == StatusRequest.success) {
        final body = response['data'];
        if (body is Map && body['data'] is Map) {
          balanceInfo = body['data'] as Map<String, dynamic>;
        } else if (body is Map && body['remaining_days'] != null) {
          balanceInfo = body as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    balanceLoading = false;
    update();
  }

  Future<void> approveLeave(int id) async {
    final response = await _leaveData.approveLeave(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'leave_approved'.tr, snackPosition: SnackPosition.BOTTOM);
      loadLeaves();
    } else {
      final msg = response['message'];
      Get.snackbar('error'.tr, msg is String ? msg : 'error_try_again'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> rejectLeave(int id, {String? reason}) async {
    final response = await _leaveData.rejectLeave(id, reason: reason);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'leave_rejected_msg'.tr, snackPosition: SnackPosition.BOTTOM);
      loadLeaves();
    } else {
      final msg = response['message'];
      Get.snackbar('error'.tr, msg is String ? msg : 'error_try_again'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> convertToAbsence(int id) async {
    final response = await _leaveData.convertToAbsence(id);
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'leave_converted_to_absence'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadLeaves();
    } else {
      final msg = response['message'];
      Get.snackbar('error'.tr,
          msg is String ? msg : 'leave_convert_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<bool> createLeave({
    required int employeeId,
    required String type,
    required DateTime startDate,
    DateTime? endDate,
    String? reason,
    bool autoApprove = false,
    String onExceed = 'split',
  }) async {
    final data = <String, dynamic>{
      'employee_id': employeeId,
      'type': type,
      'start_date': _fmt(startDate),
      'end_date': _fmt(endDate ?? startDate),
      'auto_approve': autoApprove,
      'on_exceed': onExceed,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      data['reason'] = reason.trim();
    }

    final response = await _leaveData.createLeave(data);

    if (response['status'] == StatusRequest.success) {
      final body = response['data'];
      Map<String, dynamic>? inner;
      if (body is Map && body['data'] is Map) {
        inner = body['data'] as Map<String, dynamic>;
      } else if (body is Map) {
        inner = body as Map<String, dynamic>;
      }

      if (inner != null && inner['warning'] == 'balance_exceeded') {
        Get.snackbar(
          'alert'.tr,
          'leave_balance_exceeded_warning'.trParams({
            'paid': '${inner['paid_days']}',
            'unpaid': '${inner['unpaid_days']}',
          }),
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      } else {
        Get.snackbar('done'.tr, 'leave_created_success'.tr,
            snackPosition: SnackPosition.BOTTOM);
      }
      loadLeaves();
      return true;
    }

    if (response['statusCode'] == 409) {
      final msg = response['message'];
      Get.snackbar(
          'error'.tr,
          msg is String
              ? msg
              : 'leave_overlap'.tr,
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    final errMsg = response['message'];
    Get.snackbar(
        'error'.tr,
        errMsg is String ? errMsg : 'leave_created_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  Future<bool> createRecurringLeave({
    required int employeeId,
    required String dayOfWeek,
    required String type,
    String? reason,
  }) async {
    final data = <String, dynamic>{
      'day_of_week': dayOfWeek,
      'type': type,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      data['reason'] = reason.trim();
    }

    final response = await _leaveData.createRecurringLeave(data);

    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'recurring_leave_created'.tr,
          snackPosition: SnackPosition.BOTTOM);
      loadLeaves();
      return true;
    }

    Get.snackbar('error'.tr, 'recurring_leave_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
    return false;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
