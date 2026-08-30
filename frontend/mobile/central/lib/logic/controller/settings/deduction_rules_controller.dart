import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/deduction_rule_data/deduction_rule_data.dart';
import '../../../data/model/deduction_rule_model.dart';

class DeductionRulesController extends GetxController {
  final DeductionRuleData _deductionRuleData = Get.find<DeductionRuleData>();

  StatusRequest status = StatusRequest.none;
  bool saving = false;

  /// Editable late-tier ladder, kept sorted ascending by threshold.
  List<LateTier> tiers = [];

  /// Days deducted per absent day. Default mirrors PayrollCalculator's
  /// absence_multiplier fallback (1.5).
  double absenceDays = 1.5;

  @override
  void onInit() {
    super.onInit();
    loadConfig();
  }

  Future<void> loadConfig() async {
    status = StatusRequest.loading;
    update();

    final response = await _deductionRuleData.getDeductionConfig();

    if (response['status'] == StatusRequest.success) {
      // Backend envelope: { status:'success', data:{ config:{...} } }.
      final body = response['data'];
      final config = (body is Map && body['data'] is Map)
          ? (body['data']['config'] as Map?)
          : null;
      final parsed = DeductionConfig.fromJson(
        (config ?? const {}).cast<String, dynamic>(),
      );
      tiers = List<LateTier>.from(parsed.tiers);
      absenceDays = parsed.absenceDays;
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void _sortTiers() =>
      tiers.sort((a, b) => a.thresholdMinutes.compareTo(b.thresholdMinutes));

  /// Adds or edits a tier, then persists immediately. Returns null on success,
  /// or an error key if the threshold clashes with an existing tier.
  String? upsertTier(LateTier tier, {LateTier? replacing}) {
    final clash = tiers.any(
      (t) => t.thresholdMinutes == tier.thresholdMinutes && t != replacing,
    );
    if (clash) return 'tier_duplicate';
    if (replacing != null) {
      final i = tiers.indexOf(replacing);
      if (i != -1) tiers[i] = tier;
    } else {
      tiers.add(tier);
    }
    _sortTiers();
    update();
    _persist();
    return null;
  }

  void removeTier(LateTier tier) {
    tiers.remove(tier);
    update();
    _persist();
  }

  // No update() here: the field owns its own text. Calling update() on every
  // keystroke would rebuild the TextField and reset the cursor.
  void setAbsenceDays(double value) {
    absenceDays = value;
  }

  /// Persist the absence rate (called when the field is submitted/blurred).
  void persistAbsence(double value) {
    absenceDays = value;
    _persist();
  }

  /// Pushes the full config (tiers + absence) to the backend. Every mutation
  /// auto-saves so the rules survive leaving the page. On failure we keep the
  /// local state (the next successful save resends everything) and surface the
  /// error instead of silently dropping the user's input.
  Future<void> _persist({bool notify = true}) async {
    saving = true;
    update();

    final response = await _deductionRuleData.saveDeductionConfig({
      'absence_days': absenceDays,
      'tiers': tiers.map((t) => t.toJson()).toList(),
    });

    saving = false;
    update();

    if (response['status'] == StatusRequest.success) {
      if (notify) {
        Get.snackbar(
          'done'.tr,
          'rules_saved'.tr,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(milliseconds: 1200),
        );
      }
    } else {
      Get.snackbar(
        'error'.tr,
        (response['message'] as String?) ?? 'an_error_occurred'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
