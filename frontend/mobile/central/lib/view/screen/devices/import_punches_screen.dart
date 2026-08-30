import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../logic/controller/devices/import_punches_controller.dart';

/// Imports a punch export from a terminal of any brand.
///
/// Laid out as the three questions in order — which branch, which file, is this
/// right — because the confirm step is the whole point: a file read with the
/// day and month swapped writes a month of attendance to the wrong dates and
/// nothing afterwards looks broken.
class ImportPunchesScreen extends StatelessWidget {
  const ImportPunchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text('import_punches'.tr)),
      body: GetBuilder<ImportPunchesController>(
        builder: (c) {
          if (c.status == StatusRequest.loading && c.branches.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Explainer(),
                const SizedBox(height: AppSpacing.s4),
                _BranchPicker(ctrl: c),
                const SizedBox(height: AppSpacing.s4),
                _FilePicker(ctrl: c),
                if (c.error != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  _ErrorBox(message: c.error!),
                ],
                if (c.preview != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  _PreviewCard(ctrl: c),
                ],
                if (c.result != null) ...[
                  const SizedBox(height: AppSpacing.s4),
                  _ResultCard(ctrl: c),
                ],
                const SizedBox(height: AppSpacing.s5),
                if (c.result == null) _ActionButton(ctrl: c),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Explainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: colors.brand),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              'import_punches_hint'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchPicker extends StatelessWidget {
  final ImportPunchesController ctrl;
  const _BranchPicker({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'import_punches_branch'.tr,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        DropdownButtonFormField<int>(
          initialValue: ctrl.branchId,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: ctrl.branches
              .map((b) => DropdownMenuItem<int>(
                    value: b.id,
                    child: Text(b.name, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: ctrl.busy ? null : ctrl.selectBranch,
        ),
      ],
    );
  }
}

class _FilePicker extends StatelessWidget {
  final ImportPunchesController ctrl;
  const _FilePicker({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasFile = ctrl.fileName != null;

    return InkWell(
      onTap: ctrl.busy ? null : ctrl.pickFile,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s4),
        decoration: BoxDecoration(
          color: hasFile ? colors.brandSubtle : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: hasFile ? colors.brand : colors.borderHairline,
            width: hasFile ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.description_outlined : Icons.upload_file_outlined,
              size: 26,
              color: hasFile ? colors.brand : colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? ctrl.fileName! : 'import_punches_choose_file'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasFile ? colors.brand : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'import_punches_formats'.tr,
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontSize: 11,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (hasFile)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: ctrl.busy ? null : ctrl.clearFile,
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final ImportPunchesController ctrl;
  const _PreviewCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final p = ctrl.preview!;

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
          Text(
            'import_punches_preview'.tr,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          _Line(
            label: 'import_punches_readable'.tr,
            value: '${p.readableRows}',
          ),
          _Line(
            label: 'import_punches_users'.tr,
            value: '${p.distinctUsers}',
          ),
          _Line(
            label: 'import_punches_period'.tr,
            value: '${_dateOnly(p.firstPunch)} → ${_dateOnly(p.lastPunch)}',
          ),
          if (p.unreadableRows > 0)
            _Line(
              label: 'import_punches_unreadable'.tr,
              value: '${p.unreadableRows}',
              warn: true,
            ),
          // The one genuinely ambiguous thing in these files. Said out loud
          // rather than assumed silently, because filing April as March is
          // invisible once it is done.
          if (p.dateOrderAmbiguous) ...[
            const SizedBox(height: AppSpacing.s3),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s3),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'import_punches_date_ambiguous'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 11,
                  height: 1.5,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _dateOnly(String value) =>
      value.length >= 10 ? value.substring(0, 10) : value;
}

class _ResultCard extends StatelessWidget {
  final ImportPunchesController ctrl;
  const _ResultCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final r = ctrl.result!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.success),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: colors.success, size: 22),
              const SizedBox(width: AppSpacing.s2),
              Text(
                'import_punches_done'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s3),
          _Line(label: 'import_punches_applied'.tr, value: '${r.applied}'),
          if (r.alreadyImported > 0)
            _Line(
              label: 'import_punches_already'.tr,
              value: '${r.alreadyImported}',
            ),
          // Not a failure: these are terminal user ids nobody has matched to an
          // employee yet. Linking them replays the punches into attendance, so
          // the screen points there instead of reporting an error.
          if (r.unmatched > 0) ...[
            _Line(
              label: 'import_punches_unmatched'.tr,
              value: '${r.unmatched}',
              warn: true,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              'import_punches_link_hint'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s3),
          OutlinedButton(
            onPressed: ctrl.reset,
            child: Text('import_punches_another'.tr),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final ImportPunchesController ctrl;
  const _ActionButton({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    if (ctrl.busy) {
      return const Center(child: CircularProgressIndicator());
    }

    // Preview first, always. The confirm button only appears once there is
    // something to confirm.
    if (ctrl.preview == null) {
      return ElevatedButton.icon(
        onPressed: ctrl.canPreview ? ctrl.runPreview : null,
        icon: const Icon(Icons.search),
        label: Text('import_punches_check'.tr),
      );
    }

    return ElevatedButton.icon(
      onPressed: ctrl.confirmImport,
      icon: const Icon(Icons.download_done),
      label: Text('import_punches_confirm'.tr),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: colors.error),
          const SizedBox(width: AppSpacing.s3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                height: 1.5,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;
  const _Line({required this.label, required this.value, this.warn = false});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 12,
              color: colors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: warn ? colors.warning : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
