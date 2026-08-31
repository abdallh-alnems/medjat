import 'dart:async';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/employee_data/employee_data.dart';
import '../../../data/model/employee_model.dart';

/// Drives the "employees in a category" screen: loads the employee list
/// filtered to a single category via the existing employees endpoint
/// (`category_id` param) with debounced search and page-based infinite scroll.
class CategoryEmployeesController extends GetxController {
  final EmployeeData _employeeData = Get.find<EmployeeData>();

  /// Max page size the backend allows (`v1/employees` clamps to 50).
  static const int _pageSize = 50;

  late final int categoryId;
  late final String categoryName;

  StatusRequest status = StatusRequest.none;
  List<EmployeeModel> employees = [];
  String searchQuery = '';

  /// True when the failure was a 403 (caller can see the category list but
  /// lacks `manage_employees`), so the UI can show a permission message
  /// instead of a generic retry screen.
  bool permissionDenied = false;

  int _page = 1;
  bool hasMore = false;
  bool isLoadingMore = false;

  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    categoryId = (args?['id'] as int?) ?? 0;
    categoryName = (args?['name'] as String?) ?? '';
    loadEmployees();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  /// Loads the first page, replacing the current list.
  Future<void> loadEmployees() async {
    status = StatusRequest.loading;
    permissionDenied = false;
    _page = 1;
    update();

    final response = await _fetchPage(_page);

    if (response['status'] == StatusRequest.success) {
      final items = _extractItems(response['data']);
      employees = items;
      hasMore = items.length >= _pageSize;
      status = StatusRequest.success;
    } else {
      permissionDenied = (response['statusCode'] as int?) == 403;
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  /// Appends the next page when the user scrolls near the bottom.
  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore || status != StatusRequest.success) return;
    isLoadingMore = true;
    update();

    final response = await _fetchPage(_page + 1);

    if (response['status'] == StatusRequest.success) {
      final items = _extractItems(response['data']);
      _page += 1;
      employees.addAll(items);
      hasMore = items.length >= _pageSize;
    } else {
      // Keep what we have; stop paginating on error to avoid a tight loop.
      hasMore = false;
    }
    isLoadingMore = false;
    update();
  }

  Future<Map<String, dynamic>> _fetchPage(int page) {
    return _employeeData.getEmployees(
      categoryId: categoryId,
      search: searchQuery.isNotEmpty ? searchQuery : null,
      page: page,
      limit: _pageSize,
    );
  }

  /// Debounced search: waits 400ms after the last keystroke before querying.
  void onSearch(String query) {
    searchQuery = query;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), loadEmployees);
  }

  List<EmployeeModel> _extractItems(dynamic raw) {
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
    return items
        .whereType<Map<String, dynamic>>()
        .map(EmployeeModel.fromJson)
        .toList();
  }
}
