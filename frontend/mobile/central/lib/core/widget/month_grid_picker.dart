import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constant/theme/app_colors.dart';
import '../constant/theme/app_spacing.dart';

/// Bottom-sheet month picker with a year stepper and a 4×3 month grid.
/// Months outside `[min, max]` are disabled. Returns the picked label month
/// (day = 1) or `null` if dismissed.
Future<DateTime?> showMonthGridPicker(
  BuildContext context, {
  required DateTime selected,
  DateTime? min,
  DateTime? max,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _MonthGridSheet(
      selected: DateTime(selected.year, selected.month),
      min: min == null ? null : DateTime(min.year, min.month),
      max: max == null ? null : DateTime(max.year, max.month),
    ),
  );
}

class _MonthGridSheet extends StatefulWidget {
  final DateTime selected;
  final DateTime? min;
  final DateTime? max;

  const _MonthGridSheet({
    required this.selected,
    this.min,
    this.max,
  });

  @override
  State<_MonthGridSheet> createState() => _MonthGridSheetState();
}

class _MonthGridSheetState extends State<_MonthGridSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.selected.year;
  }

  bool _isAllowed(DateTime m) {
    if (widget.min != null && m.isBefore(widget.min!)) return false;
    if (widget.max != null && m.isAfter(widget.max!)) return false;
    return true;
  }

  bool get _canPrevYear {
    if (widget.min == null) return true;
    return _year > widget.min!.year;
  }

  bool get _canNextYear {
    if (widget.max == null) return true;
    return _year < widget.max!.year;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s4,
        AppSpacing.s5,
      ),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.s3),
            decoration: BoxDecoration(
              color: colors.borderHairline,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          _yearBar(colors),
          const SizedBox(height: AppSpacing.s3),
          _monthGrid(colors),
        ],
      ),
    );
  }

  Widget _yearBar(AppColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed:
              _canPrevYear ? () => setState(() => _year--) : null,
          icon: const Icon(Icons.chevron_right),
          color: colors.textSecondary,
          disabledColor: colors.textTertiary,
        ),
        SizedBox(
          width: 80,
          child: Center(
            child: Text(
              '$_year',
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed:
              _canNextYear ? () => setState(() => _year++) : null,
          icon: const Icon(Icons.chevron_left),
          color: colors.textSecondary,
          disabledColor: colors.textTertiary,
        ),
      ],
    );
  }

  Widget _monthGrid(AppColorScheme colors) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.s2,
        crossAxisSpacing: AppSpacing.s2,
        childAspectRatio: 2.1,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final m = i + 1;
        final candidate = DateTime(_year, m);
        final enabled = _isAllowed(candidate);
        final isSelected = candidate.year == widget.selected.year &&
            candidate.month == widget.selected.month;

        return Material(
          color: isSelected
              ? colors.brand
              : (enabled ? colors.surface : colors.sunken),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled
                ? () => Navigator.of(context).pop(candidate)
                : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? colors.brand
                      : colors.borderHairline,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'month_$m'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (enabled
                          ? colors.textPrimary
                          : colors.textTertiary),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
