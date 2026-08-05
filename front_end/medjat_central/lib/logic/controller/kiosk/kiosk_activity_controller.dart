import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/kiosk_data/kiosk_data.dart';

/// Kiosk identification activity, and the score distribution behind it.
///
/// This screen exists so the matching threshold can be set from what a branch
/// actually produces. The shipped defaults were derived from a public face
/// dataset — they are a starting hypothesis, and a company that never reads
/// this is running on somebody else's numbers.
class KioskActivityController extends GetxController {
  KioskActivityController({this.branchId});

  final int? branchId;

  final KioskData _data = Get.find<KioskData>();

  StatusRequest status = StatusRequest.none;
  List<Map<String, dynamic>> logs = [];
  List<Map<String, dynamic>> buckets = [];

  int matchedAttempts = 0;
  int rejectedAttempts = 0;
  double defaultThreshold = 0.55;
  double defaultMargin = 0.08;

  /// Only failures, when the admin wants to see what is going wrong.
  bool onlyFailures = false;

  /// Attempts that resolved nobody, or resolved ambiguously. A branch where
  /// this climbs has a physical problem — a smeared lens, a dead light — far
  /// more often than a tuning problem.
  int get failureCount => logs
      .where((l) => l['result'] != 'matched')
      .length;

  double get failureRate => logs.isEmpty ? 0 : failureCount / logs.length;

  /// The point at which a branch is worth looking at rather than reading.
  bool get failureRateAbnormal => logs.length >= 20 && failureRate > 0.25;

  /// Attempts the margin rule refused because two people scored too close.
  /// Distinct from "not recognised": these are the ones that would have been
  /// attributed to the wrong person by a threshold-only design.
  int get ambiguousCount =>
      logs.where((l) => l['result'] == 'ambiguous').length;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status = StatusRequest.loading;
    update();

    final results = await Future.wait([
      _data.recognitionLogs(
        branchId: branchId,
        result: onlyFailures ? null : null,
        limit: 200,
      ),
      _data.scoreDistribution(branchId: branchId),
    ]);

    final logResponse = results[0];
    if (logResponse['status'] == StatusRequest.success) {
      final data = _unwrap(logResponse['data']);
      logs = _mapList(data is Map ? data['logs'] : null);
      status = StatusRequest.success;
    } else {
      status = logResponse['status'] as StatusRequest;
    }

    final distResponse = results[1];
    if (distResponse['status'] == StatusRequest.success) {
      final data = _unwrap(distResponse['data']);
      if (data is Map) {
        buckets = _mapList(data['buckets']);
        final summary = data['summary'];
        if (summary is Map) {
          matchedAttempts = (summary['matched_attempts'] as num?)?.toInt() ?? 0;
          rejectedAttempts =
              (summary['rejected_attempts'] as num?)?.toInt() ?? 0;
          final defaults = summary['current_defaults'];
          if (defaults is Map) {
            defaultThreshold =
                (defaults['threshold'] as num?)?.toDouble() ?? 0.55;
            defaultMargin = (defaults['margin'] as num?)?.toDouble() ?? 0.08;
          }
        }
      }
    }

    update();
  }

  void toggleOnlyFailures() {
    onlyFailures = !onlyFailures;
    update();
  }

  List<Map<String, dynamic>> get visibleLogs => onlyFailures
      ? logs.where((l) => l['result'] != 'matched').toList()
      : logs;

  /// Fetches the stored capture for one attempt.
  ///
  /// Returns a base64 data URI, or null when the retention window has passed —
  /// which is a normal outcome, not an error: evidence is deliberately finite.
  Future<String?> capture(int recognitionLogId) async {
    final response = await _data.capture(recognitionLogId: recognitionLogId);
    if (response['status'] != StatusRequest.success) return null;

    final data = _unwrap(response['data']);
    return data is Map ? data['image_base64'] as String? : null;
  }

  static List<Map<String, dynamic>> _mapList(dynamic raw) => raw is List
      ? raw
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : <Map<String, dynamic>>[];

  static dynamic _unwrap(dynamic data) =>
      data is Map && data.containsKey('data') ? data['data'] : data;
}
