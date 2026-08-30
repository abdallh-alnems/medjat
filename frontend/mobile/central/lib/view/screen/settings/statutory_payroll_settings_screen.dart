import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/settings/statutory_payroll_settings_controller.dart';

class StatutoryPayrollSettingsScreen extends StatelessWidget {
  const StatutoryPayrollSettingsScreen({super.key});

  static const _decimal = TextInputType.numberWithOptions(decimal: true);

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(StatutoryPayrollSettingsController());

    return Scaffold(
      appBar: AppBar(title: Text('statutory_settings_title'.tr)),
      body: GetBuilder<StatutoryPayrollSettingsController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.loadSettings,
            widget: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('statutory_settings_hint'.tr,
                      style: AppTextStyles.sm(context)),
                  const SizedBox(height: AppSpacing.s5),

                  // ── Social insurance ──
                  _switchTile(
                    context,
                    title: 'statutory_si_title'.tr,
                    subtitle: 'statutory_si_hint'.tr,
                    value: ctrl.socialInsuranceEnabled,
                    onChanged: ctrl.setSocialInsuranceEnabled,
                  ),
                  if (ctrl.socialInsuranceEnabled) ...[
                    const SizedBox(height: AppSpacing.s3),
                    PrimaryInput(
                      label: 'statutory_si_employee_rate'.tr,
                      controller: ctrl.siEmployeeRateController,
                      keyboardType: _decimal,
                      inputFormatters: _rateFormatters,
                      hint: '0',
                    ),
                    const SizedBox(height: AppSpacing.s3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: PrimaryInput(
                            label: 'statutory_si_min_wage'.tr,
                            controller: ctrl.siMinWageController,
                            keyboardType: _decimal,
                            inputFormatters: _moneyFormatters,
                            hint: '0',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s3),
                        Expanded(
                          child: PrimaryInput(
                            label: 'statutory_si_max_wage'.tr,
                            controller: ctrl.siMaxWageController,
                            keyboardType: _decimal,
                            inputFormatters: _moneyFormatters,
                            hint: '0',
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppSpacing.s5),

                  // ── Income tax ──
                  _switchTile(
                    context,
                    title: 'statutory_tax_title'.tr,
                    subtitle: 'statutory_tax_hint'.tr,
                    value: ctrl.incomeTaxEnabled,
                    onChanged: ctrl.setIncomeTaxEnabled,
                  ),
                  if (ctrl.incomeTaxEnabled) ...[
                    const SizedBox(height: AppSpacing.s3),
                    PrimaryInput(
                      label: 'statutory_tax_exemption'.tr,
                      controller: ctrl.taxExemptionController,
                      keyboardType: _decimal,
                      inputFormatters: _moneyFormatters,
                      hint: '0',
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text('statutory_tax_brackets_title'.tr,
                        style: AppTextStyles.h3(context)),
                    const SizedBox(height: AppSpacing.s1),
                    Text('statutory_tax_brackets_hint'.tr,
                        style: AppTextStyles.sm(context)),
                    const SizedBox(height: AppSpacing.s3),
                    for (var i = 0; i < ctrl.taxBrackets.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: PrimaryInput(
                                label: 'statutory_tax_bracket_upto'.tr,
                                controller:
                                    ctrl.taxBrackets[i].upToController,
                                keyboardType: _decimal,
                                inputFormatters: _moneyFormatters,
                                hint: 'statutory_tax_bracket_upto_hint'.tr,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s3),
                            Expanded(
                              child: PrimaryInput(
                                label: 'statutory_tax_bracket_rate'.tr,
                                controller:
                                    ctrl.taxBrackets[i].rateController,
                                keyboardType: _decimal,
                                inputFormatters: _rateFormatters,
                                hint: '0',
                              ),
                            ),
                            IconButton(
                              onPressed: () => ctrl.removeBracket(i),
                              icon: const Icon(Icons.remove_circle_outline),
                              color: AppColors.of(context).error,
                              tooltip: 'delete'.tr,
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: ctrl.addBracket,
                        icon: const Icon(Icons.add, size: 18),
                        label: Text('statutory_tax_add_bracket'.tr),
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.s5),

                  // ── End-of-service benefit ──
                  _switchTile(
                    context,
                    title: 'statutory_eosb_title'.tr,
                    subtitle: 'statutory_eosb_hint'.tr,
                    value: ctrl.eosbEnabled,
                    onChanged: ctrl.setEosbEnabled,
                  ),
                  if (ctrl.eosbEnabled) ...[
                    const SizedBox(height: AppSpacing.s3),
                    PrimaryInput(
                      label: 'statutory_eosb_days'.tr,
                      controller: ctrl.eosbDaysController,
                      keyboardType: _decimal,
                      inputFormatters: _moneyFormatters,
                      hint: '21',
                    ),
                  ],

                  const SizedBox(height: AppSpacing.s6),
                  PrimaryButton(
                    text: 'save'.tr,
                    isLoading: ctrl.saving,
                    onPressed: ctrl.saveSettings,
                  ),
                  const SizedBox(height: AppSpacing.s5),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Allow ASCII, Arabic-Indic (٠-٩) and Persian (۰-۹) digits plus a decimal
  // point; the controller normalises non-ASCII digits before parsing.
  static final _numberFormatters = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp('[0-9.٠-٩۰-۹]')),
  ];
  static final _rateFormatters = _numberFormatters;
  static final _moneyFormatters = _numberFormatters;

  Widget _switchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SwitchListTile(
          title: Text(title,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              )),
          subtitle: Text(subtitle, style: AppTextStyles.sm(context)),
          value: value,
          onChanged: onChanged,
          activeThumbColor: colors.brand,
        ),
      ),
    );
  }
}
