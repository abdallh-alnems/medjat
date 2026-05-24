import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/live_attendance_data/live_attendance_data.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../data/model/live_attendance_model.dart';

class LiveAttendanceController extends GetxController {
  final LiveAttendanceData _data = Get.find<LiveAttendanceData>();
  final BranchData _branchData = Get.find<BranchData>();

  static const Duration _refreshInterval = Duration(seconds: 25);

  StatusRequest status = StatusRequest.none;
  List<LiveAttendanceEntry> entries = [];
  LiveAttendanceSummary summary = LiveAttendanceSummary();
  DateTime? lastUpdated;

  // Branch filter (server-side scope).
  int? selectedBranchId;
  int? selectedShiftId;
  int? selectedCategoryId;
  final List<Map<String, dynamic>> branches = [];

  // Client-side filters.
  String searchQuery = '';
  LiveStatus? statusFilter;

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _loadBranches();
    loadBoard();
    _startAutoRefresh();
  }

  @override
  void onClose() {
    _timer?.cancel();
    _timer = null;
    super.onClose();
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(_refreshInterval, (_) => loadBoard(silent: true));
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
      debugPrint('LiveAttendance branches error: $e');
    }
  }

  /// [silent] keeps the current list visible while refreshing in the
  /// background (used by the timer) instead of showing the loading state.
  Future<void> loadBoard({bool silent = false}) async {
    if (!silent) {
      status = StatusRequest.loading;
      update();
    }

    final response = await _data.getLiveBoard(
      branchId: selectedBranchId,
      shiftId: selectedShiftId,
      categoryId: selectedCategoryId,
    );

    if (response['status'] == StatusRequest.success) {
      final payload = _unwrap(response['data']);
      if (payload != null) {
        final rawList = payload['employees'];
        if (rawList is List) {
          entries = rawList
              .map((e) =>
                  LiveAttendanceEntry.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
        final rawSummary = payload['summary'];
        if (rawSummary is Map) {
          summary = LiveAttendanceSummary.fromJson(
              Map<String, dynamic>.from(rawSummary));
        }
        final serverTime = payload['server_time'];
        lastUpdated = serverTime is String
            ? (DateTime.tryParse(serverTime)?.toLocal() ?? DateTime.now())
            : DateTime.now();
      }
      status = StatusRequest.success;
    } else if (!silent) {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
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

  void selectBranch(int? branchId) {
    selectedBranchId = branchId;
    loadBoard();
  }

  void syncFilters({int? branchId, int? shiftId, int? categoryId}) {
    selectedBranchId = branchId;
    selectedShiftId = shiftId;
    selectedCategoryId = categoryId;
    loadBoard();
  }

  void setSearch(String query) {
    searchQuery = query;
    update();
  }

  void setStatusFilter(LiveStatus? filter) {
    statusFilter = filter;
    update();
  }

  List<LiveAttendanceEntry> get filteredEntries {
    final q = searchQuery.trim().toLowerCase();
    return entries.where((e) {
      if (statusFilter != null && e.status != statusFilter) return false;
      if (q.isNotEmpty && !e.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }
}
