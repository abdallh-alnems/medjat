import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/company_settings_data/company_settings_data.dart';

/// One row of the progressive income-tax ladder. [upToController] empty means
/// "no ceiling" (the top, open-ended bracket).
class TaxBracketRow {
  final TextEditingController upToController;
  final TextEditingController rateController;

  TaxBracketRow({String? upTo, String? rate})
      : upToController = TextEditingController(text: upTo ?? ''),
        rateController = TextEditingController(text: rate ?? '');

  void dispose() {
    upToController.dispose();
    rateController.dispose();
  }
}

class StatutoryPayrollSettingsController extends GetxController {
  final CompanySettingsData _data = Get.find<CompanySettingsData>();

  StatusRequest status = StatusRequest.none;
  bool saving = false;

  // ── Social insurance ──
  bool socialInsuranceEnabled = false;
  final siEmployeeRateController = TextEditingController();
  final siMinWageController = TextEditingController();
  final siMaxWageController = TextEditingController();

  // ── Income tax ──
  bool incomeTaxEnabled = false;
  final taxExemptionController = TextEditingController();
  final List<TaxBracketRow> taxBrackets = [];

  // ── End-of-service benefit ──
  bool eosbEnabled = false;
  final eosbDaysController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  @override
  void onClose() {
    siEmployeeRateController.dispose();
    siMinWageController.dispose();
    siMaxWageController.dispose();
    taxExemptionController.dispose();
    eosbDaysController.dispose();
    for (final b in taxBrackets) {
      b.dispose();
    }
    super.onClose();
  }

  String _numText(dynamic v) {
    if (v == null) return '';
    final n = (v as num).toDouble();
    // Drop the trailing ".0" so whole numbers read cleanly.
    return n == n.truncateToDouble() ? n.toInt().toString() : n.toString();
  }

  /// Like [_numText] but shows "0" for an unset value, so the admin starts
  /// from a concrete zero instead of an empty box.
  String _numTextOrZero(dynamic v) => v == null ? '0' : _numText(v);

  Future<void> loadSettings() async {
    status = StatusRequest.loading;
    update();

    final response = await _data.getStatutoryPayrollSettings();

    if (response['status'] == StatusRequest.success) {
      dynamic body = response['data'];
      if (body is Map && body['data'] is Map) body = body['data'];
      if (body is Map) {
        socialInsuranceEnabled =
            (body['social_insurance_enabled'] as bool?) ?? false;
        siEmployeeRateController.text = _numTextOrZero(body['si_employee_rate']);
        siMinWageController.text = _numTextOrZero(body['si_min_wage']);
        siMaxWageController.text = _numTextOrZero(body['si_max_wage']);

        incomeTaxEnabled = (body['income_tax_enabled'] as bool?) ?? false;
        taxExemptionController.text = _numTextOrZero(body['tax_personal_exemption']);

        for (final b in taxBrackets) {
          b.dispose();
        }
        taxBrackets.clear();
        final brackets = body['income_tax_brackets'];
        if (brackets is List) {
          for (final raw in brackets) {
            if (raw is Map) {
              taxBrackets.add(TaxBracketRow(
                upTo: _numText(raw['up_to']),
                rate: _numText(raw['rate']),
              ));
            }
          }
        }

        eosbEnabled = (body['eosb_enabled'] as bool?) ?? false;
        eosbDaysController.text = _numTextOrZero(body['eosb_days_per_year']);
      }
      status = StatusRequest.success;
    } else {
      status = (response['status'] as StatusRequest?) ?? StatusRequest.failure;
    }
    update();
  }

  void setSocialInsuranceEnabled(bool value) {
    socialInsuranceEnabled = value;
    update();
  }

  void setIncomeTaxEnabled(bool value) {
    incomeTaxEnabled = value;
    if (value && taxBrackets.isEmpty) {
      taxBrackets.add(TaxBracketRow(rate: '0'));
    }
    update();
  }

  void setEosbEnabled(bool value) {
    eosbEnabled = value;
    update();
  }

  void addBracket() {
    taxBrackets.add(TaxBracketRow());
    update();
  }

  void removeBracket(int index) {
    if (index < 0 || index >= taxBrackets.length) return;
    taxBrackets.removeAt(index).dispose();
    update();
  }

  void _err(String key) {
    Get.snackbar('error'.tr, key.tr, snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> saveSettings() async {
    final data = <String, dynamic>{
      'social_insurance_enabled': socialInsuranceEnabled,
      'income_tax_enabled': incomeTaxEnabled,
      'eosb_enabled': eosbEnabled,
    };

    if (socialInsuranceEnabled) {
      final empRate = _parse(siEmployeeRateController.text);
      if (empRate == null || empRate < 0 || empRate > 100) {
        _err('statutory_si_rate_invalid');
        return;
      }
      final minWage = _optMoney(siMinWageController.text);
      final maxWage = _optMoney(siMaxWageController.text);
      if (minWage == _invalid || maxWage == _invalid) {
        _err('statutory_si_wage_invalid');
        return;
      }
      if (minWage != null && maxWage != null && maxWage < minWage) {
        _err('statutory_si_wage_order_invalid');
        return;
      }
      data['si_employee_rate'] = empRate;
      data['si_min_wage'] = minWage;
      data['si_max_wage'] = maxWage;
    }

    if (incomeTaxEnabled) {
      if (taxBrackets.isEmpty) {
        _err('statutory_tax_brackets_required');
        return;
      }
      final exemption = _optMoney(taxExemptionController.text);
      if (exemption == _invalid) {
        _err('statutory_tax_exemption_invalid');
        return;
      }
      final brackets = <Map<String, dynamic>>[];
      for (final b in taxBrackets) {
        final upToText = b.upToController.text.trim();
        double? upTo;
        if (upToText.isNotEmpty) {
          upTo = _parse(upToText);
          if (upTo == null || upTo < 0) {
            _err('statutory_tax_bracket_invalid');
            return;
          }
        }
        final rate = _parse(b.rateController.text);
        if (rate == null || rate < 0 || rate > 100) {
          _err('statutory_tax_bracket_invalid');
          return;
        }
        brackets.add({'up_to': upTo, 'rate': rate});
      }

      // Only the top tier may be open-ended (empty ceiling).
      if (brackets.where((b) => b['up_to'] == null).length > 1) {
        _err('statutory_tax_open_bracket_invalid');
        return;
      }

      // Sort ascending by ceiling, open bracket last — matches the calculator.
      brackets.sort((a, b) {
        if (a['up_to'] == null) return 1;
        if (b['up_to'] == null) return -1;
        return (a['up_to'] as double).compareTo(b['up_to'] as double);
      });

      // Ceilings must be strictly increasing (no duplicates).
      double? prevCeiling;
      for (final b in brackets) {
        final u = b['up_to'] as double?;
        if (u == null) continue;
        if (prevCeiling != null && u <= prevCeiling) {
          _err('statutory_tax_bracket_order_invalid');
          return;
        }
        prevCeiling = u;
      }

      data['tax_personal_exemption'] = exemption;
      data['income_tax_brackets'] = brackets;
    }

    if (eosbEnabled) {
      final days = _parse(eosbDaysController.text);
      if (days == null || days < 0 || days > 366) {
        _err('statutory_eosb_days_invalid');
        return;
      }
      data['eosb_days_per_year'] = days;
    }

    saving = true;
    update();

    final response = await _data.updateStatutoryPayrollSettings(data);

    saving = false;
    if (response['status'] == StatusRequest.success) {
      Get.snackbar('done'.tr, 'statutory_settings_saved'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('error'.tr, (response['message'] as String?) ?? 'error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
    update();
  }

  // Sentinel distinguishing "left blank" (null) from "typed something invalid".
  static const double _invalid = double.nan;

  /// null = blank, [_invalid] = present but not a valid amount, else the value.
  double? _optMoney(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final n = _parse(t);
    if (n == null || n < 0) return _invalid;
    return n;
  }

  /// Parses a number after converting Arabic-Indic (٠-٩) and Persian (۰-۹)
  /// digits to ASCII, so values typed on an Arabic keyboard are accepted.
  double? _parse(String text) => double.tryParse(_normalizeDigits(text.trim()));

  String _normalizeDigits(String input) {
    final sb = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        sb.writeCharCode(0x30 + (rune - 0x0660)); // Arabic-Indic
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        sb.writeCharCode(0x30 + (rune - 0x06F0)); // Persian
      } else {
        sb.writeCharCode(rune);
      }
    }
    return sb.toString();
  }
}
