import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/dashboard_data/dashboard_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/data_source/remote/shift_data/shift_data.dart';
import '../../../data/model/dashboard_model.dart';
import '../../../data/model/employee_category_model.dart';
import '../../../data/model/shift_model.dart';
import '../live_attendance/live_attendance_controller.dart';

class DashboardController extends GetxController {
  final DashboardData _dashboardData = Get.find<DashboardData>();
  final BranchData _branchData = Get.find<BranchData>();
  final CategoryData _categoryData = Get.find<CategoryData>();
  final ShiftData _shiftData = Get.find<ShiftData>();

  StatusRequest status = StatusRequest.none;
  DashboardModel? dashboard;
  int? selectedBranchId;
  int? selectedShiftId;
  int? selectedCategoryId;
  BranchMetric selectedMetric = BranchMetric.attendanceRate;

  final List<Map<String, dynamic>> branches = [];
  final List<EmployeeCategoryModel> categories = [];
  final List<ShiftModel> shifts = [];

  /// Number of active customizations applied to the dashboard view.
  int get activeFilterCount =>
      (selectedBranchId != null ? 1 : 0) +
      (selectedShiftId != null ? 1 : 0) +
      (selectedCategoryId != null ? 1 : 0);

  bool get hasAnyFilterOptions =>
      branches.isNotEmpty || shifts.isNotEmpty || categories.isNotEmpty;

  /// Shifts available for the currently selected branch. Shifts with no
  /// branch (tenant-wide) always show; branch-scoped shifts only when their
  /// branch matches the selected one.
  List<ShiftModel> shiftsForBranch(int? branchId) {
    if (branchId == null) return shifts;
    return shifts
        .where((s) => s.branchId == null || s.branchId == branchId)
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    _loadBranches();
    _loadShifts();
    _loadCategories();
    loadDashboard();
    try {
      Get.find<LiveAttendanceController>();
    } catch (_) {}
  }

  Future<void> _loadShifts() async {
    try {
      final response = await _shiftData.getShifts();
      if (response['status'] == StatusRequest.success) {
        dynamic payload = response['data'];
        if (payload is Map && payload['data'] != null) payload = payload['data'];
        List<dynamic>? items;
        if (payload is List) {
          items = payload;
        } else if (payload is Map) {
          for (final key in const ['items', 'records', 'list', 'shifts', 'data']) {
            if (payload[key] is List) {
              items = payload[key] as List;
              break;
            }
          }
        }
        if (items != null) {
          shifts
            ..clear()
            ..addAll(items.map((e) =>
                ShiftModel.fromJson(Map<String, dynamic>.from(e as Map))));
          update();
        }
      }
    } catch (e) {
      debugPrint('Dashboard shifts error: $e');
    }
  }

  Future<void> _loadBranches() async {
    try {
      final response = await _branchData.getBranches();
      if (response['status'] == StatusRequest.success) {
        final payload = _unwrap(response['data']);
        final raw = payload?['branches'];
        if (raw is List) {
          branches
            ..clear()
            ..addAll(raw.map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map)));
          update();
        }
      }
    } catch (e) {
      debugPrint('Dashboard branches error: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _categoryData.getCategories();
      if (response['status'] == StatusRequest.success) {
        dynamic body = response['data'];
        if (body is Map && body['data'] is Map) {
          body = body['data'];
        }
        if (body is Map && body['categories'] is List) {
          categories
            ..clear()
            ..addAll((body['categories'] as List)
                .map((e) => EmployeeCategoryModel.fromJson(
                    e as Map<String, dynamic>))
                .toList());
        } else if (body is List) {
          categories
            ..clear()
            ..addAll(body
                .map((e) => EmployeeCategoryModel.fromJson(
                    e as Map<String, dynamic>))
                .toList());
        }
        update();
      }
    } catch (e) {
      debugPrint('Dashboard categories error: $e');
    }
  }

  Future<void> loadDashboard() async {
    status = StatusRequest.loading;
    update();

    final response = await _dashboardData.getDashboardFiltered(
      branchId: selectedBranchId,
      shiftId: selectedShiftId,
      categoryId: selectedCategoryId,
    );

    if (response['status'] == StatusRequest.success) {
      // CRUD returns the full envelope ({status, data}); unwrap to the inner
      // payload before parsing, otherwise every metric reads as null/0.
      final payload = _unwrap(response['data']);
      if (payload != null) {
        dashboard = DashboardModel.fromJson(payload);
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  /// Applies any combination of branch / shift / category at once
  /// (e.g. "evening shift of a specific branch") and refreshes the view.
  void applyFilters({int? branchId, int? shiftId, int? categoryId}) {
    selectedBranchId = branchId;
    selectedShiftId = shiftId;
    selectedCategoryId = categoryId;
    // Drop a shift selection that no longer belongs to the chosen branch.
    if (selectedShiftId != null &&
        !shiftsForBranch(branchId).any((s) => s.id == selectedShiftId)) {
      selectedShiftId = null;
    }
    loadDashboard();
    _syncLiveAttendanceFilters();
  }

  void clearFilters() => applyFilters();

  void selectMetric(BranchMetric metric) {
    selectedMetric = metric;
    update();
  }

  void _syncLiveAttendanceFilters() {
    try {
      final liveCtrl = Get.find<LiveAttendanceController>();
      liveCtrl.syncFilters(
        branchId: selectedBranchId,
        shiftId: selectedShiftId,
        categoryId: selectedCategoryId,
      );
    } catch (_) {}
  }

  Map<String, dynamic>? _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final inner = body['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return body;
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }
}
