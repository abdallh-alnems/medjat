import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/audit_data/audit_data.dart';
import '../../../data/model/audit_log_model.dart';

class AuditController extends GetxController {
  final AuditData _data = Get.find<AuditData>();

  StatusRequest status = StatusRequest.none;
  StatusRequest moreStatus = StatusRequest.none;

  final List<AuditLogModel> entries = [];
  final List<AuditActor> actors = [];

  int? adminFilter;
  String? categoryFilter;

  int _page = 1;
  bool hasMore = false;

  @override
  void onInit() {
    super.onInit();
    loadActivity();
  }

  /// Loads (or reloads) the first page for the current filters.
  Future<void> loadActivity() async {
    status = StatusRequest.loading;
    _page = 1;
    update();

    final response = await _data.getActivity(
      page: _page,
      adminId: adminFilter,
      category: categoryFilter,
    );

    if (response['status'] == StatusRequest.success) {
      final data = _unwrap(response['data']);
      entries
        ..clear()
        ..addAll(_parseItems(data));
      // The actor list only arrives with page 1; keep it across filter changes.
      final rawActors = data['actors'];
      if (rawActors is List) {
        actors
          ..clear()
          ..addAll(rawActors
              .whereType<Map<String, dynamic>>()
              .map(AuditActor.fromJson));
      }
      hasMore = data['has_more'] == true;
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  /// Appends the next page (infinite scroll).
  Future<void> loadMore() async {
    if (!hasMore || moreStatus == StatusRequest.loading) return;
    moreStatus = StatusRequest.loading;
    update();

    final next = _page + 1;
    final response = await _data.getActivity(
      page: next,
      adminId: adminFilter,
      category: categoryFilter,
    );

    if (response['status'] == StatusRequest.success) {
      final data = _unwrap(response['data']);
      entries.addAll(_parseItems(data));
      hasMore = data['has_more'] == true;
      _page = next;
      moreStatus = StatusRequest.success;
    } else {
      moreStatus = StatusRequest.failure;
    }
    update();
  }

  void filterByAdmin(int? adminId) {
    adminFilter = adminId;
    loadActivity();
  }

  void filterByCategory(String? category) {
    categoryFilter = category;
    loadActivity();
  }

  Map<String, dynamic> _unwrap(dynamic raw) {
    dynamic payload = raw;
    if (payload is Map && payload['data'] is Map) {
      payload = payload['data'];
    }
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return <String, dynamic>{};
  }

  List<AuditLogModel> _parseItems(Map<String, dynamic> data) {
    final raw = data['items'];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AuditLogModel.fromJson)
        .toList();
  }
}
