import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';

/// Quick period presets shared by the report screens (attendance, leaves...).
enum ReportPeriod { today, thisWeek, thisMonth, lastMonth, custom }

/// A practical date-range selector built from quick preset chips
/// (today / this week / this month / last month) plus a custom range option.
///
/// Replaces the full-screen [showDateRangePicker]-only flow that was hard to
/// use for the common case of picking the current month.
class ReportPeriodSelector extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final void Function(DateTime start, DateTime end) onChanged;

  const ReportPeriodSelector({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onChanged,
  });

  @override
  State<ReportPeriodSelector> createState() => _ReportPeriodSelectorState();
}

class _ReportPeriodSelectorState extends State<ReportPeriodSelector> {
  late ReportPeriod _selected;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    _start = widget.startDate;
    _end = widget.endDate;
    _selected = _detectPeriod(_start, _end);
  }

  /// Match the incoming range against the known presets so the right chip
  /// starts selected; otherwise treat it as a custom range.
  ReportPeriod _detectPeriod(DateTime start, DateTime end) {
    for (final p in [
      ReportPeriod.today,
      ReportPeriod.thisWeek,
      ReportPeriod.thisMonth,
      ReportPeriod.lastMonth,
    ]) {
      final r = _rangeFor(p);
      if (r != null && _sameDay(r.$1, start) && _sameDay(r.$2, end)) return p;
    }
    return ReportPeriod.custom;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Returns the (start, end) range for a preset, or null for [custom].
  (DateTime, DateTime)? _rangeFor(ReportPeriod p) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (p) {
      case ReportPeriod.today:
        return (today, today);
      case ReportPeriod.thisWeek:
        // Week starts on Saturday (regional convention).
        final daysFromSaturday = (now.weekday - DateTime.saturday + 7) % 7;
        final start = today.subtract(Duration(days: daysFromSaturday));
        return (start, today);
      case ReportPeriod.thisMonth:
        return (DateTime(now.year, now.month, 1), today);
      case ReportPeriod.lastMonth:
        final firstOfThis = DateTime(now.year, now.month, 1);
        final lastMonthEnd = firstOfThis.subtract(const Duration(days: 1));
        final lastMonthStart =
            DateTime(lastMonthEnd.year, lastMonthEnd.month, 1);
        return (lastMonthStart, lastMonthEnd);
      case ReportPeriod.custom:
        return null;
    }
  }

  String _labelFor(ReportPeriod p) {
    switch (p) {
      case ReportPeriod.today:
        return 'today'.tr;
      case ReportPeriod.thisWeek:
        return 'this_week'.tr;
      case ReportPeriod.thisMonth:
        return 'this_month'.tr;
      case ReportPeriod.lastMonth:
        return 'last_month'.tr;
      case ReportPeriod.custom:
        return 'custom'.tr;
    }
  }

  Future<void> _onTap(ReportPeriod p) async {
    if (p == ReportPeriod.custom) {
      final picked = await showModalBottomSheet<DateTimeRange>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _MonthYearRangeSheet(start: _start, end: _end),
      );
      if (picked != null) {
        setState(() {
          _selected = ReportPeriod.custom;
          _start = picked.start;
          _end = picked.end;
        });
        widget.onChanged(picked.start, picked.end);
      }
      return;
    }
    final range = _rangeFor(p)!;
    setState(() {
      _selected = p;
      _start = range.$1;
      _end = range.$2;
    });
    widget.onChanged(range.$1, range.$2);
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.s2,
            runSpacing: AppSpacing.s2,
            children: ReportPeriod.values
                .map((p) => _PeriodChip(
                      label: _labelFor(p),
                      selected: _selected == p,
                      colors: colors,
                      onTap: () => _onTap(p),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.s2),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.s1),
              Text(
                '${_fmtDate(_start)}  —  ${_fmtDate(_end)}',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
        decoration: BoxDecoration(
          color: selected ? colors.brand : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? colors.brand : colors.borderHairline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that picks a period as a "from month/year" → "to month/year"
/// range, much faster than a day-level calendar for multi-month spans.
class _MonthYearRangeSheet extends StatefulWidget {
  final DateTime start;
  final DateTime end;
  const _MonthYearRangeSheet({required this.start, required this.end});

  @override
  State<_MonthYearRangeSheet> createState() => _MonthYearRangeSheetState();
}

class _MonthYearRangeSheetState extends State<_MonthYearRangeSheet> {
  late int _fromMonth;
  late int _fromYear;
  late int _toMonth;
  late int _toYear;

  static const int _firstYear = 2024;

  @override
  void initState() {
    super.initState();
    _fromMonth = widget.start.month;
    _fromYear = widget.start.year;
    _toMonth = widget.end.month;
    _toYear = widget.end.year;
  }

  List<int> get _years =>
      [for (int y = _firstYear; y <= DateTime.now().year; y++) y];

  // Month ordinal used to compare two (year, month) pairs.
  int get _fromKey => _fromYear * 12 + _fromMonth;
  int get _toKey => _toYear * 12 + _toMonth;

  /// Keep start <= end: editing "from" past "to" pushes "to" up to match.
  void _clampAfterFromChange() {
    if (_fromKey > _toKey) {
      _toMonth = _fromMonth;
      _toYear = _fromYear;
    }
  }

  /// Keep start <= end: editing "to" before "from" pulls "from" down to match.
  void _clampAfterToChange() {
    if (_toKey < _fromKey) {
      _fromMonth = _toMonth;
      _fromYear = _toYear;
    }
  }

  void _apply() {
    final start = DateTime(_fromYear, _fromMonth, 1);
    // Last day of the "to" month.
    var end = DateTime(_toYear, _toMonth + 1, 0);
    // Never query past today.
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (end.isAfter(todayDate)) end = todayDate;
    Navigator.of(context).pop(DateTimeRange(start: start, end: end));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4, AppSpacing.s3, AppSpacing.s4, AppSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.s3),
                decoration: BoxDecoration(
                  color: colors.borderHairline,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Text(
              'select_period'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            _RangeRow(
              label: 'from'.tr,
              month: _fromMonth,
              year: _fromYear,
              years: _years,
              colors: colors,
              onMonth: (m) => setState(() {
                _fromMonth = m;
                _clampAfterFromChange();
              }),
              onYear: (y) => setState(() {
                _fromYear = y;
                _clampAfterFromChange();
              }),
            ),
            const SizedBox(height: AppSpacing.s3),
            _RangeRow(
              label: 'to'.tr,
              month: _toMonth,
              year: _toYear,
              years: _years,
              colors: colors,
              onMonth: (m) => setState(() {
                _toMonth = m;
                _clampAfterToChange();
              }),
              onYear: (y) => setState(() {
                _toYear = y;
                _clampAfterToChange();
              }),
            ),
            const SizedBox(height: AppSpacing.s5),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(
                  'apply'.tr,
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  final String label;
  final int month;
  final int year;
  final List<int> years;
  final AppColorScheme colors;
  final ValueChanged<int> onMonth;
  final ValueChanged<int> onYear;

  const _RangeRow({
    required this.label,
    required this.month,
    required this.year,
    required this.years,
    required this.colors,
    required this.onMonth,
    required this.onYear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: _PickerBox<int>(
            value: month,
            items: [for (int m = 1; m <= 12; m++) m],
            label: (m) => 'month_$m'.tr,
            onChanged: onMonth,
            colors: colors,
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        Expanded(
          flex: 2,
          child: _PickerBox<int>(
            value: year,
            items: years,
            label: (y) => '$y',
            onChanged: onYear,
            colors: colors,
          ),
        ),
      ],
    );
  }
}

class _PickerBox<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final AppColorScheme colors;

  const _PickerBox({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: colors.textTertiary),
          dropdownColor: colors.surface,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e,
                    child: Text(label(e)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
