import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/crew_member_model.dart';
import '../../../logic/controller/attendance/crew_controller.dart';

/// A supervisor marks the people on site with them.
///
/// Built for a phone held in one hand, in sun, by somebody who is also doing
/// their actual job. Rows are large, the state of each person is visible
/// without tapping anything, and the primary action stays pinned to the bottom
/// so it is reachable with a thumb no matter how long the crew is.
class CrewScreen extends StatelessWidget {
  const CrewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text('crew_title'.tr)),
      body: SafeArea(
        child: GetBuilder<CrewController>(
          builder: (ctrl) {
            if (ctrl.status == StatusRequest.loading && ctrl.members.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (ctrl.status == StatusRequest.failure && ctrl.members.isEmpty) {
              return _Message(
                icon: Icons.error_outline,
                color: colors.error,
                text: ctrl.errorMessage ?? 'error_try_again'.tr,
                actionLabel: 'try_again'.tr,
                onAction: ctrl.load,
              );
            }

            // No crew and not a supervisor are the same state on the server, so
            // they are the same message here.
            if (ctrl.members.isEmpty) {
              return _Message(
                icon: Icons.groups_outlined,
                color: colors.textTertiary,
                text: 'crew_empty'.tr,
                actionLabel: 'refresh'.tr,
                onAction: ctrl.load,
              );
            }

            return Column(
              children: [
                _SelectionBar(ctrl: ctrl, colors: colors),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: ctrl.load,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s4,
                        vertical: AppSpacing.s3,
                      ),
                      itemCount: ctrl.members.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.s2),
                      itemBuilder: (_, i) => _MemberTile(
                        member: ctrl.members[i],
                        selected: ctrl.selected.contains(ctrl.members[i].id),
                        onTap: () => ctrl.toggle(ctrl.members[i].id),
                        colors: colors,
                      ),
                    ),
                  ),
                ),
                _SubmitBar(ctrl: ctrl, colors: colors),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Count + select-all, and the summary of what the last submission actually did.
class _SelectionBar extends StatelessWidget {
  final CrewController ctrl;
  final AppColorScheme colors;

  const _SelectionBar({required this.ctrl, required this.colors});

  @override
  Widget build(BuildContext context) {
    final skippedCount = ctrl.lastSkipped.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'crew_selected_count'.trParams({
                    'count': ctrl.selected.length.toString(),
                    'total': ctrl.members.length.toString(),
                  }),
                  style: AppTextStyles.body(context),
                ),
              ),
              TextButton(
                onPressed: ctrl.selectAllActionable,
                child: Text('crew_select_all'.tr),
              ),
            ],
          ),
          // Shown after a submission so "28 recorded, 2 already marked" is
          // visible rather than a success that quietly hid the two.
          if (ctrl.lastRecordedCount > 0 || skippedCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s2),
              child: Text(
                'crew_last_result'.trParams({
                  'recorded': ctrl.lastRecordedCount.toString(),
                  'skipped': skippedCount.toString(),
                }),
                style: TextStyle(
                  fontFamily: AppTextStyles.arabicFamily,
                  fontSize: 12,
                  color: skippedCount > 0 ? colors.warning : colors.success,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final CrewMemberModel member;
  final bool selected;
  final VoidCallback onTap;
  final AppColorScheme colors;

  const _MemberTile({
    required this.member,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final done = member.isDayDone;

    return Material(
      color: selected ? colors.brand.withValues(alpha: 0.08) : colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? colors.brand : colors.borderHairline,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        // A finished day is still tappable on purpose: the server, not the
        // phone, decides what is a duplicate, and a supervisor who taps one
        // gets told rather than finding the row inert with no explanation.
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s3),
          child: Row(
            children: [
              Checkbox(value: selected, onChanged: (_) => onTap()),
              const SizedBox(width: AppSpacing.s2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: TextStyle(
                        fontFamily: AppTextStyles.arabicFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: done ? colors.textTertiary : colors.textPrimary,
                      ),
                    ),
                    if (member.jobTitle != null &&
                        member.jobTitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        member.jobTitle!,
                        style: TextStyle(
                          fontFamily: AppTextStyles.arabicFamily,
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _StateBadge(member: member, colors: colors),
            ],
          ),
        ),
      ),
    );
  }
}

/// Today's state, readable at a glance so the supervisor never has to remember
/// who they already did.
class _StateBadge extends StatelessWidget {
  final CrewMemberModel member;
  final AppColorScheme colors;

  const _StateBadge({required this.member, required this.colors});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;

    if (member.isDayDone) {
      label = 'crew_state_done'.tr;
      color = colors.textTertiary;
    } else if (member.isCheckedIn) {
      label = member.checkInTime!.substring(0, 5);
      color = colors.success;
    } else {
      label = 'crew_state_not_in'.tr;
      color = colors.textTertiary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTextStyles.latinFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  final CrewController ctrl;
  final AppColorScheme colors;

  const _SubmitBar({required this.ctrl, required this.colors});

  @override
  Widget build(BuildContext context) {
    final enabled = ctrl.selected.isNotEmpty && !ctrl.isSubmitting;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderHairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ctrl.errorMessage != null) ...[
            Text(
              ctrl.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTextStyles.arabicFamily,
                fontSize: 12,
                color: colors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
          ],
          if (ctrl.photoRequired)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_camera_outlined,
                      size: 14, color: colors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    'crew_photo_will_be_asked'.tr,
                    style: TextStyle(
                      fontFamily: AppTextStyles.arabicFamily,
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: enabled ? ctrl.submit : null,
              child: ctrl.isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      ctrl.isCheckOutMode
                          ? 'crew_record_check_out'.trParams(
                              {'count': ctrl.selected.length.toString()})
                          : 'crew_record_check_in'.trParams(
                              {'count': ctrl.selected.length.toString()}),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _Message({
    required this.icon,
    required this.color,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: color),
          const SizedBox(height: AppSpacing.s4),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(context),
          ),
          const SizedBox(height: AppSpacing.s5),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
