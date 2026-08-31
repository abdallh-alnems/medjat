import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/live_attendance_data/live_attendance_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/data_source/remote/shift_data/shift_data.dart';
import '../../../data/data_source/remote/category_data/category_data.dart';
import '../../../data/model/live_attendance_model.dart';
import '../../../data/model/shift_model.dart';
import '../../../data/model/employee_category_model.dart';

enum EmployeeStatusFilter { present, absent, late, checkedOut, notArrived, inside, leave }

class StatusEmployeesController extends GetxController {
  final LiveAttendanceData _liveData = Get.find<LiveAttendanceData>();
  final BranchData _branchData = Get.find<BranchData>();
  final ShiftData _shiftData = Get.find<ShiftData>();
  final CategoryData _categoryData = Get.find<CategoryData>();

  late EmployeeStatusFilter statusFilter;
  String _title = '';

  StatusRequest status = StatusRequest.none;
  List<LiveAttendanceEntry> allEntries = [];
  String searchQuery = '';

  int? selectedBranchId;
  int? selectedShiftId;
  int? selectedCategoryId;

  final List<Map<String, dynamic>> branches = [];
  final List<ShiftModel> shifts = [];
  final List<EmployeeCategoryModel> categories = [];

  int get activeFilterCount =>
      (selectedBranchId != null ? 1 : 0) +
      (selectedShiftId != null ? 1 : 0) +
      (selectedCategoryId != null ? 1 : 0);

  bool get hasAnyFilterOptions =>
      branches.isNotEmpty || shifts.isNotEmpty || categories.isNotEmpty;

  String get title => _title;

  List<ShiftModel> shiftsForBranch(int? branchId) {
    if (branchId == null) return shifts;
    return shifts
        .where((s) => s.branchId == null || s.branchId == branchId)
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    statusFilter = args?['filter'] as EmployeeStatusFilter? ?? EmployeeStatusFilter.present;
    _title = args?['title'] as String? ?? '';
    _loadFilterOptions();
    loadEmployees();
  }

  Future<void> _loadFilterOptions() async {
    await Future.wait([
      _loadBranches(),
      _loadShifts(),
      _loadCategories(),
    ]);
    update();
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
        }
      }
    } catch (e) {
      debugPrint('StatusEmployees branches error: $e');
    }
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
        }
      }
    } catch (e) {
      debugPrint('StatusEmployees shifts error: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _categoryData.getCategories();
      if (response['status'] == StatusRequest.success) {
        dynamic body = response['data'];
        if (body is Map && body['data'] is Map) body = body['data'];
        if (body is Map && body['categories'] is List) {
          categories
            ..clear()
            ..addAll((body['categories'] as List)
                .map((e) =>
                    EmployeeCategoryModel.fromJson(e as Map<String, dynamic>))
                .toList());
        } else if (body is List) {
          categories
            ..clear()
            ..addAll(body
                .map((e) =>
                    EmployeeCategoryModel.fromJson(e as Map<String, dynamic>))
                .toList());
        }
      }
    } catch (e) {
      debugPrint('StatusEmployees categories error: $e');
    }
  }

  Future<void> loadEmployees() async {
    status = StatusRequest.loading;
    update();

    final response = await _liveData.getLiveBoard(
      branchId: selectedBranchId,
      shiftId: selectedShiftId,
      categoryId: selectedCategoryId,
    );

    if (response['status'] == StatusRequest.success) {
      final payload = _unwrap(response['data']);
      if (payload != null) {
        final rawList = payload['employees'];
        if (rawList is List) {
          allEntries = rawList
              .map((e) =>
                  LiveAttendanceEntry.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  List<LiveAttendanceEntry> get filteredEntries {
    var list = allEntries.where((e) {
      switch (statusFilter) {
        case EmployeeStatusFilter.present:
          return e.status == LiveStatus.inside;
        case EmployeeStatusFilter.absent:
          // Confirmed absences only, matching the dashboard "absent" card
          // (v1/dashboard/overview's absent_today). No-shows with no record yet are
          // "not arrived" and live under the separate notArrived filter.
          return e.status == LiveStatus.absent;
        case EmployeeStatusFilter.late:
          return e.isLate;
        case EmployeeStatusFilter.checkedOut:
          return e.status == LiveStatus.out;
        case EmployeeStatusFilter.notArrived:
          return e.status == LiveStatus.notIn;
        case EmployeeStatusFilter.inside:
          return e.status == LiveStatus.inside;
        case EmployeeStatusFilter.leave:
          return e.status == LiveStatus.leave;
      }
    }).toList();

    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) => e.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void onSearch(String query) {
    searchQuery = query;
    update();
  }

  void applyFilters({int? branchId, int? shiftId, int? categoryId}) {
    selectedBranchId = branchId;
    selectedShiftId = shiftId;
    selectedCategoryId = categoryId;
    if (selectedShiftId != null &&
        !shiftsForBranch(branchId).any((s) => s.id == selectedShiftId)) {
      selectedShiftId = null;
    }
    loadEmployees();
  }

  void clearFilters() => applyFilters();

  String? branchName(int? id) {
    if (id == null) return null;
    for (final b in branches) {
      if ((b['id'] as num?)?.toInt() == id) return b['name'] as String?;
    }
    return null;
  }

  String? shiftName(int? id) {
    if (id == null) return null;
    for (final s in shifts) {
      if (s.id == id) return s.name;
    }
    return null;
  }

  String? categoryName(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return null;
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
