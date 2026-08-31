import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../core/class/handling_data_request.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/shared/buttons/primary_button.dart';
import '../../../core/shared/input_fields/primary_input.dart';
import '../../../logic/controller/settings/company_settings_controller.dart';

/// ISO currency codes offered in the picker. Labels come from `curr_<code>`.
const List<String> _kCurrencies = [
  'EGP',
  'SAR',
  'AED',
  'USD',
  'EUR',
  'KWD',
  'QAR',
];

String _currencyLabel(String code) {
  final name = 'curr_${code.toLowerCase()}'.tr;
  return '$name ($code)';
}

/// Human label for a timezone id, localized to the active app language:
///  - Curated full names for common zones (key `tz_<id>`) take precedence.
///  - Otherwise the region (continent) is translated, the city is prettified,
///    and the current GMT offset is appended, e.g. Arabic → "آسيا / Riyadh (GMT+3)".
String _timezoneLabel(String id) {
  final key = 'tz_${id.toLowerCase().replaceAll('/', '_')}';
  final curated = key.tr;
  if (curated != key) return curated;

  final parts = id.split('/');
  final regionKey = 'tzregion_${parts.first.toLowerCase()}';
  final regionTr = regionKey.tr;
  final region = regionTr != regionKey ? regionTr : parts.first;
  final city = parts.length > 1
      ? parts.sublist(1).join(' / ').replaceAll('_', ' ')
      : '';
  final name = city.isEmpty ? region : '$region / $city';
  final offset = _gmtOffset(id);
  return offset.isEmpty ? name : '$name ($offset)';
}

/// Current GMT offset for a zone (e.g. "GMT+3"), from the bundled tz database.
String _gmtOffset(String id) {
  try {
    final totalMinutes = tz.getLocation(id).currentTimeZone.offset.inMinutes;
    final sign = totalMinutes < 0 ? '-' : '+';
    final abs = totalMinutes.abs();
    final hours = abs ~/ 60;
    final minutes = abs % 60;
    final mm = minutes == 0 ? '' : ':${minutes.toString().padLeft(2, '0')}';
    return 'GMT$sign$hours$mm';
  } catch (_) {
    return '';
  }
}

// Week start weekday options (ISO: 1=Mon..7=Sun), ordered Saturday-first to
// match the Arab work week shown by default.
const List<String> _kWeekdayOrder = ['6', '7', '1', '2', '3', '4', '5'];

const Map<int, String> _kWeekdayKeys = {
  1: 'weekday_mon',
  2: 'weekday_tue',
  3: 'weekday_wed',
  4: 'weekday_thu',
  5: 'weekday_fri',
  6: 'weekday_sat',
  7: 'weekday_sun',
};

String _weekdayLabel(int isoWeekday) =>
    (_kWeekdayKeys[isoWeekday] ?? 'weekday_sat').tr;

class CompanySettingsScreen extends StatelessWidget {
  const CompanySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(CompanySettingsController());

    return Scaffold(
      appBar: AppBar(title: Text('company_data'.tr)),
      body: GetBuilder<CompanySettingsController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.loadSettings,
            widget: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('company_data'.tr, style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s4),
                  PrimaryInput(
                    label: 'company_name'.tr,
                    controller: ctrl.nameController,
                  ),

                  // ── Currency & timezone ──
                  const SizedBox(height: AppSpacing.s6),
                  Text('localization_section'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s4),
                  _PickerField(
                    label: 'currency_label'.tr,
                    value: _currencyLabel(ctrl.currency),
                    icon: Icons.attach_money,
                    onTap: () => _pickOption(
                      context,
                      title: 'currency_label'.tr,
                      options: _kCurrencies,
                      selected: ctrl.currency,
                      labelOf: _currencyLabel,
                      onSelected: ctrl.setCurrency,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  _PickerField(
                    label: 'timezone_label'.tr,
                    value: _timezoneLabel(ctrl.timezone),
                    icon: Icons.public,
                    onTap: () => _pickTimezone(context, ctrl),
                  ),
                  if (ctrl.timezoneAutoDetected) ...[
                    const SizedBox(height: AppSpacing.s2),
                    Row(
                      children: [
                        Icon(Icons.my_location,
                            size: 14, color: AppColors.of(context).brand),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text('timezone_auto_detected'.tr,
                              style: AppTextStyles.sm(context)),
                        ),
                      ],
                    ),
                  ],

                  // ── Attendance cycle ──
                  const SizedBox(height: AppSpacing.s6),
                  Text('attendance_cycle'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Text('cycle_start_day_hint'.tr,
                      style: AppTextStyles.sm(context)),
                  const SizedBox(height: AppSpacing.s3),
                  _CycleStartDayField(ctrl: ctrl),

                  // ── Weekly schedule ──
                  const SizedBox(height: AppSpacing.s6),
                  Text('weekly_schedule'.tr,
                      style: AppTextStyles.h3(context)),
                  const SizedBox(height: AppSpacing.s2),
                  Text('week_start_day_hint'.tr,
                      style: AppTextStyles.sm(context)),
                  const SizedBox(height: AppSpacing.s3),
                  _PickerField(
                    label: 'week_start_day_label'.tr,
                    value: _weekdayLabel(ctrl.weekStartDay),
                    icon: Icons.calendar_view_week,
                    onTap: () => _pickOption(
                      context,
                      title: 'week_start_day_label'.tr,
                      options: _kWeekdayOrder,
                      selected: ctrl.weekStartDay.toString(),
                      labelOf: (o) => _weekdayLabel(int.parse(o)),
                      onSelected: (o) => ctrl.setWeekStartDay(int.parse(o)),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s6),
                  PrimaryButton(
                    text: 'save_changes'.tr,
                    isLoading: ctrl.status == StatusRequest.loading,
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

  /// Shows a bottom-sheet list of [options] and reports the chosen value.
  void _pickOption(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selected,
    required String Function(String) labelOf,
    required void Function(String) onSelected,
  }) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s4),
              child: Text(title, style: AppTextStyles.h3(context)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options.map((o) {
                  final isSelected = o == selected;
                  return ListTile(
                    title: Text(
                      labelOf(o),
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? colors.brand
                            : colors.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: colors.brand)
                        : null,
                    onTap: () {
                      onSelected(o);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
          ],
        ),
      ),
    );
  }

  /// Searchable picker over the full IANA timezone list loaded from the device.
  void _pickTimezone(BuildContext context, CompanySettingsController ctrl) {
    final colors = AppColors.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final all = ctrl.availableTimezones;
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setState) {
            final filtered = query.isEmpty
                ? all
                : all
                    .where((tz) =>
                        tz.toLowerCase().contains(query) ||
                        _timezoneLabel(tz).toLowerCase().contains(query))
                    .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.75,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.s4),
                        child: Text('timezone_label'.tr,
                            style: AppTextStyles.h3(context)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s4),
                        child: TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'search'.tr,
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          onChanged: (v) =>
                              setState(() => query = v.trim().toLowerCase()),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s2),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final tz = filtered[i];
                            final isSelected = tz == ctrl.timezone;
                            return ListTile(
                              title: Text(
                                _timezoneLabel(tz),
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Sans Arabic',
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? colors.brand
                                      : colors.textPrimary,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check, color: colors.brand)
                                  : null,
                              onTap: () {
                                ctrl.setTimezone(tz);
                                Navigator.of(ctx).pop();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// A read-only field that opens a picker when tapped (used for currency/timezone).
class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s2),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.04,
              color: colors.textSecondary,
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s3,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colors.textTertiary),
                const SizedBox(width: AppSpacing.s3),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(Icons.expand_more, size: 20, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A compact stepper (− value +) for the company cycle start day (1-28).
class _CycleStartDayField extends StatelessWidget {
  final CompanySettingsController ctrl;
  const _CycleStartDayField({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GetBuilder<CompanySettingsController>(
      builder: (_) {
        final from = ctrl.cycleStartDay;
        final previewText = from <= 1
            ? 'cycle_normal_month'.tr
            : 'cycle_window_preview'
                .trParams({'from': '$from', 'to': '${from - 1}'});
        return Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: colors.borderHairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'cycle_start_day_label'.tr,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: from > 1
                        ? () => ctrl.setCycleStartDay(from - 1)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    color: colors.brand,
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$from',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colors.brand,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: from < 28
                        ? () => ctrl.setCycleStartDay(from + 1)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    color: colors.brand,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(previewText, style: AppTextStyles.sm(context)),
            ],
          ),
        );
      },
    );
  }
}

