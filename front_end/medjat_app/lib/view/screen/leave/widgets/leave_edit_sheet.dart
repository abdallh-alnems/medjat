import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../logic/controller/leave/leave_controller.dart';

Future<void> showLeaveEditSheet(
  BuildContext context,
  LeaveController controller,
  Map<String, dynamic> leave,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LeaveEditSheet(controller: controller, leave: leave),
  );
}

class _LeaveEditSheet extends StatefulWidget {
  final LeaveController controller;
  final Map<String, dynamic> leave;

  const _LeaveEditSheet({required this.controller, required this.leave});

  @override
  State<_LeaveEditSheet> createState() => _LeaveEditSheetState();
}

class _LeaveEditSheetState extends State<_LeaveEditSheet> {
  late String _type;
  late TextEditingController _reasonCtrl;
  late bool _rangeMode;
  DateTime? _singleDate;
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _type = (widget.leave['type'] as String?) ?? 'annual';
    _reasonCtrl =
        TextEditingController(text: widget.leave['reason']?.toString() ?? '');

    final start = DateTime.tryParse(widget.leave['start_date']?.toString() ?? '');
    final end = DateTime.tryParse(widget.leave['end_date']?.toString() ?? '');
    if (start != null && end != null && end != start) {
      _rangeMode = true;
      _range = DateTimeRange(start: start, end: end);
    } else {
      _rangeMode = false;
      _singleDate = start;
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Material(
              color: colors.surface,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('edit_leave'.tr, style: AppTextStyles.h3(context)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration: InputDecoration(
                        labelText: 'leave_type'.tr,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'annual', child: Text('annual'.tr)),
                        DropdownMenuItem(value: 'sick', child: Text('sick'.tr)),
                        DropdownMenuItem(
                            value: 'personal', child: Text('personal'.tr)),
                        DropdownMenuItem(
                            value: 'unpaid', child: Text('unpaid'.tr)),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _type = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text('leave_single_day'.tr),
                          selected: !_rangeMode,
                          onSelected: (_) => setState(() => _rangeMode = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('leave_period_mode'.tr),
                          selected: _rangeMode,
                          onSelected: (_) => setState(() => _rangeMode = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText:
                              _rangeMode ? 'leave_period'.tr : 'date'.tr,
                          border: const OutlineInputBorder(),
                          suffixIcon: Icon(_rangeMode
                              ? Icons.date_range
                              : Icons.calendar_today),
                        ),
                        child: Text(
                          _dateLabel(),
                          style: _dateChosen()
                              ? AppTextStyles.body(context)
                              : AppTextStyles.bodySecondary(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'reason_optional'.tr,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GetBuilder<LeaveController>(
                      init: widget.controller,
                      builder: (ctrl) => PrimaryButton(
                        text: 'save'.tr,
                        isLoading: ctrl.applyStatus == StatusRequest.loading,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _dateChosen() => _rangeMode ? _range != null : _singleDate != null;

  String _dateLabel() {
    if (_rangeMode) {
      if (_range == null) return 'choose_period'.tr;
      return '${_fmt(_range!.start)}  →  ${_fmt(_range!.end)}'
          '   (${'leave_days_count'.trParams({'count': '${_range!.duration.inDays + 1}'})})';
    }
    return _singleDate == null ? 'choose_date'.tr : _fmt(_singleDate!);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = now.add(const Duration(days: 365));
    if (_rangeMode) {
      final picked = await showDateRangePicker(
        context: context,
        initialDateRange: _range,
        firstDate: firstDate,
        lastDate: lastDate,
      );
      if (picked != null) setState(() => _range = picked);
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: _singleDate ?? now,
        firstDate: firstDate,
        lastDate: lastDate,
      );
      if (picked != null) setState(() => _singleDate = picked);
    }
  }

  Future<void> _submit() async {
    final String start;
    final String end;
    if (_rangeMode) {
      if (_range == null) {
        Get.snackbar('error'.tr, 'choose_date'.tr,
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      start = _fmt(_range!.start);
      end = _fmt(_range!.end);
    } else {
      if (_singleDate == null) {
        Get.snackbar('error'.tr, 'choose_date'.tr,
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      start = _fmt(_singleDate!);
      end = start;
    }

    final ok = await widget.controller.updateLeave(
      id: (widget.leave['id'] as num).toInt(),
      type: _type,
      startDate: start,
      endDate: end,
      reason: _reasonCtrl.text.isEmpty ? null : _reasonCtrl.text,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }
}
