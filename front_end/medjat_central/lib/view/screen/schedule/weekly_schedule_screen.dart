import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../data/model/schedule_model.dart';
import '../../../data/model/shift_model.dart';
import '../../../logic/controller/schedule/schedule_controller.dart';

/// Day-focused weekly roster, styled after professional shift-scheduling apps:
/// the manager picks one day from the top strip and works a clean, colour-coded
/// list of employees. Each card also carries a compact 7-cell week strip, so the
/// at-a-glance overview survives without a horizontal spreadsheet. Branch / role
/// / shift filters and multi-select drive bulk assignment.
class WeeklyScheduleScreen extends StatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  final ScheduleController ctrl = Get.find<ScheduleController>();

  /// Stable accent colours assigned to shifts by their order in the palette,
  /// so "morning / evening / night" stay visually distinct across the screen.
  static const List<Color> _shiftPalette = [
    Color(0xFF0D7377),
    Color(0xFFB8860B),
    Color(0xFF6C5CE7),
    Color(0xFFE17055),
    Color(0xFF2E86DE),
    Color(0xFF00B894),
    Color(0xFFD63384),
    Color(0xFFE67E22),
  ];

  int? _selectedDay; // 0..6, resolved lazily to "today"
  final Set<int> _selected = <int>{}; // employee ids picked for bulk assign

  // Filters (client-side over the loaded week).
  int? _branchFilter;
  String? _roleFilter;
  int? _shiftFilter;

  bool get _hasFilters =>
      _branchFilter != null || _roleFilter != null || _shiftFilter != null;

  int _resolveDay() {
    final n = ctrl.days.length;
    if (n == 0) return 0;
    if (_selectedDay != null) return _selectedDay!.clamp(0, n - 1);
    final idx = ctrl.days.indexOf(_todayStr());
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Text('weekly_schedule'.tr),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _hasFilters,
              backgroundColor: colors.brand,
              child: const Icon(Icons.tune),
            ),
            tooltip: 'filter'.tr,
            onPressed: () => _showFilterSheet(context),
          ),
          GetBuilder<ScheduleController>(
            builder: (_) => TextButton(
              onPressed: ctrl.busy ? null : () => _confirmPublish(context),
              child: Text(
                'publish'.tr,
                style: TextStyle(
                  color: ctrl.hasDraftCells ? colors.brand : colors.textTertiary,
                  fontFamily: AppTextStyles.arabicFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: GetBuilder<ScheduleController>(
        builder: (_) {
          final day = _resolveDay();
          final date = ctrl.days.isEmpty ? '' : ctrl.days[day];
          final visible = _filtered();
          return Column(
            children: [
              _weekBar(context),
              _daySelector(context, day),
              if (_hasFilters) _activeFilters(context),
              Divider(height: 1, color: colors.borderHairline),
              Expanded(
                child: HandlingDataRequest(
                  statusRequest: ctrl.status,
                  onRetry: ctrl.loadWeek,
                  widget: ctrl.employees.isEmpty
                      ? _emptyState(context, filtered: false)
                      : Column(
                          children: [
                            _dayToolbar(context, date, visible),
                            Expanded(
                              child: visible.isEmpty
                                  ? _emptyState(context, filtered: true)
                                  : _dayList(context, date, visible),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _selected.isEmpty ? null : _bulkBar(context),
    );
  }

  // ── week navigation + copy ──────────────────────────────────────────────

  Widget _weekBar(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: ctrl.busy ? null : ctrl.previousWeek,
            tooltip: 'previous'.tr,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_d(ctrl.weekStartStr)} – ${_d(ctrl.weekEndStr)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppTextStyles.latinFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_isCurrentWeek())
                  Text(
                    'this_week'.tr,
                    style: TextStyle(
                      fontFamily: AppTextStyles.arabicFamily,
                      fontSize: 11,
                      color: colors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: ctrl.busy ? null : ctrl.nextWeek,
            tooltip: 'next'.tr,
          ),
          IconButton(
            icon: Icon(Icons.copy_all_outlined, size: 20, color: colors.brand),
            onPressed: ctrl.busy ? null : () => _copyPrevious(context),
            tooltip: 'copy_previous_week'.tr,
          ),
        ],
      ),
    );
  }

  // ── day selector strip ──────────────────────────────────────────────────

  Widget _daySelector(BuildContext context, int selected) {
    final colors = AppColors.of(context);
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s2,
        AppSpacing.s1,
        AppSpacing.s2,
        AppSpacing.s3,
      ),
      child: Row(
        children: [
          for (var i = 0; i < ctrl.days.length; i++)
            Expanded(child: _dayPill(context, i, selected)),
        ],
      ),
    );
  }

  Widget _dayPill(BuildContext context, int i, int selected) {
    final colors = AppColors.of(context);
    final date = ctrl.days[i];
    final isSel = i == selected;
    final isToday = date == _todayStr();
    final has = _assignedCount(date) > 0;

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AppMotion.micro,
        curve: AppMotion.easing,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s2),
        decoration: BoxDecoration(
          color: isSel ? colors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isToday && !isSel ? colors.brand : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            Text(
              _dayInitial(date),
              style: TextStyle(
                fontFamily: AppTextStyles.arabicFamily,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSel ? Colors.white : colors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _dayNum(date),
              style: TextStyle(
                fontFamily: AppTextStyles.latinFamily,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSel ? Colors.white : colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: has
                    ? (isSel ? Colors.white : colors.brand)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── day summary + select-all toolbar ──────────────────────────────────────

  Widget _dayToolbar(
    BuildContext context,
    String date,
    List<RosterEmployee> visible,
  ) {
    final colors = AppColors.of(context);
    var working = 0;
    var rest = 0;
    var none = 0;
    for (final e in visible) {
      final c = ctrl.cellFor(e.id, date);
      if (c == null) {
        none++;
      } else if (c.isRest) {
        rest++;
      } else {
        working++;
      }
    }
    final allSelected =
        visible.isNotEmpty && visible.every((e) => _selected.contains(e.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s3,
        AppSpacing.s2,
        AppSpacing.s1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: AppSpacing.s2,
              runSpacing: 4,
              children: [
                _summaryChip(context, '$working', 'on_duty'.tr, colors.success),
                _summaryChip(context, '$rest', 'rest_day'.tr, colors.textTertiary),
                if (none > 0)
                  _summaryChip(context, '$none', 'not_assigned'.tr, colors.warning),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: visible.isEmpty
                ? null
                : () => setState(() {
                      if (allSelected) {
                        _selected.removeAll(visible.map((e) => e.id));
                      } else {
                        _selected.addAll(visible.map((e) => e.id));
                      }
                    }),
            icon: Icon(
              allSelected ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: colors.brand,
            ),
            label: Text(
              'select_all'.tr,
              style: TextStyle(
                fontFamily: AppTextStyles.arabicFamily,
                fontSize: 12,
                color: colors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(BuildContext context, String n, String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            n,
            style: TextStyle(
              fontFamily: AppTextStyles.latinFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTextStyles.arabicFamily,
              fontSize: 12,
              color: AppColors.of(context).textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── employee list for the focused day ───────────────────────────────────

  Widget _dayList(
    BuildContext context,
    String date,
    List<RosterEmployee> visible,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        AppSpacing.s2,
        AppSpacing.s4,
        AppSpacing.s8,
      ),
      itemCount: visible.length,
      itemBuilder: (_, i) => _employeeCard(context, visible[i], date),
    );
  }

  Widget _employeeCard(BuildContext context, RosterEmployee emp, String date) {
    final colors = AppColors.of(context);
    final cell = ctrl.cellFor(emp.id, date);
    final isSel = _selected.contains(emp.id);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isSel ? colors.brand : colors.borderHairline,
          width: isSel ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => _pickCell(context, emp, date),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _selectAvatar(context, emp, cell, isSel),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTextStyles.arabicFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_subtitle(emp).isNotEmpty)
                            Text(
                              _subtitle(emp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.xs(context),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    _dayStatus(context, cell),
                  ],
                ),
                const SizedBox(height: AppSpacing.s3),
                _weekStrip(context, emp, date),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Circular avatar that doubles as the multi-select toggle.
  Widget _selectAvatar(
    BuildContext context,
    RosterEmployee emp,
    ScheduleCell? cell,
    bool isSel,
  ) {
    final colors = AppColors.of(context);
    final accent = cell != null && !cell.isRest
        ? _shiftColor(cell.shiftId)
        : colors.textSecondary;
    return GestureDetector(
      onTap: () => setState(
        () => isSel ? _selected.remove(emp.id) : _selected.add(emp.id),
      ),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSel ? colors.brand : accent.withValues(alpha: 0.14),
          border: Border.all(
            color: isSel ? colors.brand : accent.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: isSel
            ? const Icon(Icons.check, size: 20, color: Colors.white)
            : Center(
                child: Text(
                  _initials(emp.name),
                  style: TextStyle(
                    fontFamily: AppTextStyles.arabicFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
      ),
    );
  }

  /// Right-aligned status for the focused day: shift block, rest, or empty.
  Widget _dayStatus(BuildContext context, ScheduleCell? cell) {
    final colors = AppColors.of(context);
    if (cell == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 15, color: colors.textTertiary),
            const SizedBox(width: 4),
            Text(
              'not_assigned'.tr,
              style: TextStyle(
                fontFamily: AppTextStyles.arabicFamily,
                fontSize: 12,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      );
    }
    if (cell.isRest) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.sunken,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bedtime_outlined, size: 14, color: colors.textSecondary),
            const SizedBox(width: 4),
            Text(
              'rest_day'.tr,
              style: TextStyle(
                fontFamily: AppTextStyles.arabicFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    final c = _shiftColor(cell.shiftId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(left: BorderSide(color: c, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            cell.shiftName ?? '',
            style: TextStyle(
              fontFamily: AppTextStyles.arabicFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
          if (cell.startTime != null)
            Text(
              '${_t(cell.startTime!)} - ${_t(cell.endTime ?? '')}',
              style: TextStyle(
                fontFamily: AppTextStyles.latinFamily,
                fontSize: 11,
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  // ── compact whole-week strip ────────────────────────────────────────────

  Widget _weekStrip(BuildContext context, RosterEmployee emp, String focused) {
    return Row(
      children: [
        for (final date in ctrl.days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _stripCell(context, emp, date, date == focused),
            ),
          ),
      ],
    );
  }

  Widget _stripCell(
    BuildContext context,
    RosterEmployee emp,
    String date,
    bool focused,
  ) {
    final colors = AppColors.of(context);
    final cell = ctrl.cellFor(emp.id, date);

    Color bg;
    Color border;
    Widget? mark;
    if (cell == null) {
      bg = Colors.transparent;
      border = colors.borderHairline;
    } else if (cell.isRest) {
      bg = colors.sunken;
      border = colors.borderHairline;
      mark = Container(
        width: 8,
        height: 2,
        decoration: BoxDecoration(
          color: colors.textTertiary,
          borderRadius: BorderRadius.circular(1),
        ),
      );
    } else {
      final c = _shiftColor(cell.shiftId);
      bg = c.withValues(alpha: 0.18);
      border = cell.isDraft ? c : c.withValues(alpha: 0.45);
      mark = Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
    }

    return GestureDetector(
      onTap: () => _pickCell(context, emp, date),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            _dayInitial(date),
            style: TextStyle(
              fontFamily: AppTextStyles.arabicFamily,
              fontSize: 9,
              fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
              color: focused ? colors.brand : colors.textTertiary,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            height: 26,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: focused ? colors.brand : border,
                width: focused ? 1.6 : 1,
              ),
            ),
            child: Center(child: mark ?? const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }

  // ── filters ───────────────────────────────────────────────────────────────

  void _showFilterSheet(BuildContext context) {
    final colors = AppColors.of(context);
    final branches = _branchOptions();
    final roles = _roleOptions();
    var branch = _branchFilter;
    var role = _roleFilter;
    var shift = _shiftFilter;

    Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, setSheet) => Container(
          padding: const EdgeInsets.all(AppSpacing.s5),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sheetHandle(context),
                Row(
                  children: [
                    Text(
                      'filter'.tr,
                      style: const TextStyle(
                        fontFamily: AppTextStyles.arabicFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (branch != null || role != null || shift != null)
                      TextButton(
                        onPressed: () => setSheet(() {
                          branch = null;
                          role = null;
                          shift = null;
                        }),
                        child: Text('clear_all'.tr),
                      ),
                  ],
                ),
                if (branches.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s3),
                  _filterLabel(context, 'branch'.tr),
                  const SizedBox(height: AppSpacing.s2),
                  _filterDropdown<int?>(
                    context,
                    value: branch,
                    hint: 'all_branches'.tr,
                    items: branches
                        .map((b) => DropdownMenuItem<int?>(
                              value: b.$1,
                              child: Text(b.$2, style: _ddStyle),
                            ))
                        .toList(),
                    onChanged: (v) => setSheet(() => branch = v),
                  ),
                ],
                if (roles.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s3),
                  _filterLabel(context, 'job_title'.tr),
                  const SizedBox(height: AppSpacing.s2),
                  _filterDropdown<String?>(
                    context,
                    value: role,
                    hint: 'all_roles'.tr,
                    items: roles
                        .map((r) => DropdownMenuItem<String?>(
                              value: r,
                              child: Text(r, style: _ddStyle),
                            ))
                        .toList(),
                    onChanged: (v) => setSheet(() => role = v),
                  ),
                ],
                if (ctrl.shifts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s3),
                  _filterLabel(context, 'shift'.tr),
                  const SizedBox(height: AppSpacing.s2),
                  _filterDropdown<int?>(
                    context,
                    value: shift,
                    hint: 'all_shifts'.tr,
                    items: ctrl.shifts
                        .map((s) => DropdownMenuItem<int?>(
                              value: s.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(left: 6),
                                    decoration: BoxDecoration(
                                      color: _shiftColor(s.id),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Flexible(child: Text(s.name, style: _ddStyle)),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setSheet(() => shift = v),
                  ),
                ],
                const SizedBox(height: AppSpacing.s5),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back<void>();
                      setState(() {
                        _branchFilter = branch;
                        _roleFilter = role;
                        _shiftFilter = shift;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('apply_filter'.tr),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _activeFilters(BuildContext context) {
    final colors = AppColors.of(context);
    final chips = <Widget>[];
    if (_branchFilter != null) {
      chips.add(_removableChip(
        context,
        _branchName(_branchFilter!),
        () => setState(() => _branchFilter = null),
      ));
    }
    if (_roleFilter != null) {
      chips.add(_removableChip(
        context,
        _roleFilter!,
        () => setState(() => _roleFilter = null),
      ));
    }
    if (_shiftFilter != null) {
      chips.add(_removableChip(
        context,
        _shiftName(_shiftFilter!),
        () => setState(() => _shiftFilter = null),
        color: _shiftColor(_shiftFilter),
      ));
    }
    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s4,
        0,
        AppSpacing.s4,
        AppSpacing.s2,
      ),
      child: Wrap(spacing: AppSpacing.s2, runSpacing: 4, children: chips),
    );
  }

  Widget _removableChip(
    BuildContext context,
    String label,
    VoidCallback onRemove, {
    Color? color,
  }) {
    final c = color ?? AppColors.of(context).brand;
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: AppTextStyles.arabicFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: c,
        ),
      ),
      deleteIcon: Icon(Icons.close, size: 15, color: c),
      onDeleted: onRemove,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: BorderSide(color: c.withValues(alpha: 0.3)),
      backgroundColor: c.withValues(alpha: 0.08),
    );
  }

  Widget _filterLabel(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          fontFamily: AppTextStyles.arabicFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.of(context).textSecondary,
        ),
      );

  Widget _filterDropdown<T>(
    BuildContext context, {
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: colors.textTertiary),
          items: [
            DropdownMenuItem<T>(
              value: null as T,
              child: Text(hint, style: _ddStyle.copyWith(color: colors.textTertiary)),
            ),
            ...items,
          ],
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }

  static const TextStyle _ddStyle = TextStyle(
    fontFamily: AppTextStyles.arabicFamily,
    fontSize: 14,
  );

  // ── cell picker ──────────────────────────────────────────────────────────

  void _pickCell(BuildContext context, RosterEmployee emp, String date) {
    final colors = AppColors.of(context);
    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(AppSpacing.s5),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetHandle(context),
            Text(
              '${emp.name} · ${_dayLabel(date)} ${_d(date)}',
              style: const TextStyle(
                fontFamily: AppTextStyles.arabicFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            ...ctrl.shifts.map(
              (s) => _shiftOption(context, s, () {
                Get.back<void>();
                ctrl.assign(employeeIds: [emp.id], dates: [date], shiftId: s.id);
              }),
            ),
            _plainOption(context, Icons.bedtime_outlined, 'rest_day'.tr, () {
              Get.back<void>();
              ctrl.assign(employeeIds: [emp.id], dates: [date]);
            }),
            if (ctrl.cellFor(emp.id, date) != null)
              _plainOption(context, Icons.clear, 'clear'.tr, () {
                Get.back<void>();
                ctrl.clearCell(emp.id, date);
              }, color: colors.error),
          ],
          ),
        ),
      ),
    );
  }

  Widget _shiftOption(BuildContext context, ShiftModel s, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: _shiftColor(s.id), shape: BoxShape.circle),
      ),
      title: Text(
        s.name,
        style: const TextStyle(
          fontFamily: AppTextStyles.arabicFamily,
          fontSize: 14,
        ),
      ),
      trailing: Text(
        '${_t(s.startTime)} - ${_t(s.endTime)}',
        style: TextStyle(
          fontFamily: AppTextStyles.latinFamily,
          fontSize: 13,
          color: AppColors.of(context).textSecondary,
        ),
      ),
    );
  }

  Widget _plainOption(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: color ?? AppColors.of(context).textSecondary),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: AppTextStyles.arabicFamily,
          fontSize: 14,
          color: color,
        ),
      ),
    );
  }

  // ── bulk assign bar ───────────────────────────────────────────────────────

  Widget _bulkBar(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      elevation: 8,
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_selected.length} ${'selected_employees'.tr}',
                  style: const TextStyle(
                    fontFamily: AppTextStyles.arabicFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(_selected.clear),
                child: Text('cancel'.tr),
              ),
              ElevatedButton.icon(
                onPressed: ctrl.busy ? null : () => _bulkAssignSheet(context),
                icon: const Icon(Icons.event_available, size: 18),
                label: Text('assign'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _bulkAssignSheet(BuildContext context) {
    final colors = AppColors.of(context);
    final chosenDays = ctrl.days.toSet().obs; // default: whole week
    final shiftId = Rxn<int>();
    final isRest = false.obs;

    Get.bottomSheet<void>(
      Container(
        padding: EdgeInsets.only(
          left: AppSpacing.s5,
          right: AppSpacing.s5,
          top: AppSpacing.s5,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s5,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetHandle(context),
              Text(
                '${'assign_to'.tr} · ${_selected.length} ${'selected_employees'.tr}',
                style: const TextStyle(
                  fontFamily: AppTextStyles.arabicFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              Text('select_days'.tr, style: AppTextStyles.bodySecondary(context)),
              const SizedBox(height: AppSpacing.s2),
              Obx(
                () => Wrap(
                  spacing: 6,
                  children: ctrl.days.map((d) {
                    final on = chosenDays.contains(d);
                    return FilterChip(
                      label: Text(_dayLabel(d), style: const TextStyle(fontSize: 11)),
                      selected: on,
                      onSelected: (_) => on ? chosenDays.remove(d) : chosenDays.add(d),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text('select_shift'.tr, style: AppTextStyles.bodySecondary(context)),
              const SizedBox(height: AppSpacing.s2),
              Obx(
                () => Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...ctrl.shifts.map((s) {
                      final on = !isRest.value && shiftId.value == s.id;
                      return ChoiceChip(
                        label: Text(s.name, style: const TextStyle(fontSize: 12)),
                        selected: on,
                        avatar: CircleAvatar(backgroundColor: _shiftColor(s.id), radius: 7),
                        onSelected: (_) {
                          isRest.value = false;
                          shiftId.value = s.id;
                        },
                      );
                    }),
                    ChoiceChip(
                      label: Text('rest_day'.tr, style: const TextStyle(fontSize: 12)),
                      selected: isRest.value,
                      onSelected: (_) {
                        isRest.value = true;
                        shiftId.value = null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s5),
              Obx(
                () => SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (chosenDays.isEmpty ||
                            (!isRest.value && shiftId.value == null))
                        ? null
                        : () async {
                            Get.back<void>();
                            final ok = await ctrl.assign(
                              employeeIds: _selected.toList(),
                              dates: chosenDays.toList(),
                              shiftId: isRest.value ? null : shiftId.value,
                            );
                            if (ok) {
                              setState(_selected.clear);
                              Get.snackbar(
                                'done'.tr,
                                'schedule_updated'.tr,
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: Colors.white,
                    ),
                    child: Text('apply'.tr),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ── actions ────────────────────────────────────────────────────────────

  void _copyPrevious(BuildContext context) {
    Get.dialog<void>(
      AlertDialog(
        title: Text('copy_previous_week'.tr),
        content: Text('copy_previous_week_confirm'.tr),
        actions: [
          TextButton(onPressed: () => Get.back<void>(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () async {
              Get.back<void>();
              final ok = await ctrl.copyPreviousWeek();
              Get.snackbar(
                'done'.tr,
                ok ? 'schedule_updated'.tr : 'error'.tr,
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: Text('copy'.tr),
          ),
        ],
      ),
    );
  }

  void _confirmPublish(BuildContext context) {
    if (!ctrl.hasDraftCells) {
      Get.snackbar(
        'publish'.tr,
        'nothing_to_publish'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.dialog<void>(
      AlertDialog(
        title: Text('publish'.tr),
        content: Text('publish_confirm'.tr),
        actions: [
          TextButton(onPressed: () => Get.back<void>(), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () async {
              Get.back<void>();
              final ok = await ctrl.publish();
              Get.snackbar(
                'done'.tr,
                ok ? 'schedule_published'.tr : 'error'.tr,
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: Text('publish'.tr),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, {required bool filtered}) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filtered ? Icons.filter_alt_off_outlined : Icons.groups_outlined,
              size: 48,
              color: colors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              filtered ? 'no_matching_employees'.tr : 'no_employees'.tr,
              style: AppTextStyles.bodySecondary(context),
            ),
            if (filtered) ...[
              const SizedBox(height: AppSpacing.s3),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  _branchFilter = null;
                  _roleFilter = null;
                  _shiftFilter = null;
                }),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text('clear_all'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sheetHandle(BuildContext context) => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: AppSpacing.s4),
          decoration: BoxDecoration(
            color: AppColors.of(context).borderStrong,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  // ── data helpers ───────────────────────────────────────────────────────

  List<RosterEmployee> _filtered() {
    Iterable<RosterEmployee> list = ctrl.employees;
    if (_branchFilter != null) {
      list = list.where((e) => e.branchId == _branchFilter);
    }
    if (_roleFilter != null) {
      list = list.where((e) => e.jobTitle == _roleFilter);
    }
    if (_shiftFilter != null) {
      // Members of the shift: the employee's home shift, OR anyone actually
      // assigned that shift somewhere in the week.
      list = list.where((e) {
        if (e.shiftId == _shiftFilter) return true;
        return ctrl.days.any((d) => ctrl.cellFor(e.id, d)?.shiftId == _shiftFilter);
      });
    }
    return list.toList();
  }

  /// Unique (branchId, branchName) pairs present in the loaded roster.
  List<(int, String)> _branchOptions() {
    final seen = <int>{};
    final out = <(int, String)>[];
    for (final e in ctrl.employees) {
      final id = e.branchId;
      if (id != null && seen.add(id)) {
        out.add((id, e.branchName ?? '#$id'));
      }
    }
    return out;
  }

  /// Unique non-empty job titles present in the loaded roster.
  List<String> _roleOptions() {
    final out = <String>{};
    for (final e in ctrl.employees) {
      final t = e.jobTitle;
      if (t != null && t.trim().isNotEmpty) out.add(t);
    }
    return out.toList()..sort();
  }

  String _branchName(int id) {
    for (final e in ctrl.employees) {
      if (e.branchId == id) return e.branchName ?? '#$id';
    }
    return '#$id';
  }

  String _shiftName(int id) =>
      ctrl.shifts.firstWhereOrNull((s) => s.id == id)?.name ?? '';

  Color _shiftColor(int? shiftId) {
    if (shiftId == null) return AppColors.light.brand;
    final idx = ctrl.shifts.indexWhere((s) => s.id == shiftId);
    if (idx < 0) return _shiftPalette.first;
    return _shiftPalette[idx % _shiftPalette.length];
  }

  String _subtitle(RosterEmployee emp) {
    final parts = <String>[
      if (emp.jobTitle != null && emp.jobTitle!.isNotEmpty) emp.jobTitle!,
      if (emp.branchName != null && emp.branchName!.isNotEmpty) emp.branchName!,
    ];
    return parts.join(' · ');
  }

  int _assignedCount(String date) {
    var n = 0;
    for (final emp in ctrl.employees) {
      final c = ctrl.cellFor(emp.id, date);
      if (c != null && !c.isRest) n++;
    }
    return n;
  }

  bool _isCurrentWeek() => ctrl.days.contains(_todayStr());

  // ── formatting helpers ───────────────────────────────────────────────────

  String _todayStr() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '؟';
    if (parts.length == 1) return parts.first.characters.take(1).toString();
    return parts.first.characters.take(1).toString() +
        parts.last.characters.take(1).toString();
  }

  String _t(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return time;
    return '${parts[0]}:${parts[1]}';
  }

  /// "2026-05-25" -> "25/05"
  String _d(String date) {
    final p = date.split('-');
    if (p.length < 3) return date;
    return '${p[2]}/${p[1]}';
  }

  /// Day-of-month as a bare number, e.g. "25".
  String _dayNum(String date) {
    final p = date.split('-');
    if (p.length < 3) return date;
    return p[2].startsWith('0') ? p[2].substring(1) : p[2];
  }

  String _dayLabel(String date) => _dayKey(date, '').tr;

  String _dayInitial(String date) => _dayKey(date, '_s').tr;

  String _dayKey(String date, String suffix) {
    final d = DateTime.tryParse(date);
    if (d == null) return '';
    const keys = ['d_mon', 'd_tue', 'd_wed', 'd_thu', 'd_fri', 'd_sat', 'd_sun'];
    return '${keys[d.weekday - 1]}$suffix';
  }
}
