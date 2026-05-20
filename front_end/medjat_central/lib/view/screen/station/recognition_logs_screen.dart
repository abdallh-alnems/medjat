import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/class/handling_data_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/station_recognition_log_model.dart';
import '../../../logic/controller/station/recognition_logs_controller.dart';

class RecognitionLogsScreen extends StatelessWidget {
  const RecognitionLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(RecognitionLogsController());

    return Scaffold(
      appBar: AppBar(title: Text('recognition_logs'.tr)),
      body: GetBuilder<RecognitionLogsController>(
        builder: (_) {
          return HandlingDataRequest(
            statusRequest: ctrl.status,
            onRetry: ctrl.load,
            widget: Column(
              children: [
                _FilterBar(ctrl: ctrl),
                Expanded(
                  child: ctrl.logs.isEmpty
                      ? Center(child: Text('no_logs'.tr, style: AppTextStyles.bodySecondary(context)))
                      : RefreshIndicator(
                          onRefresh: () => ctrl.load(),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.s4),
                            itemCount: ctrl.logs.length,
                            itemBuilder: (_, i) => _LogTile(log: ctrl.logs[i]),
                          ),
                        ),
                ),
                if (ctrl.total > ctrl.limit)
                  _Pagination(ctrl: ctrl),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final RecognitionLogsController ctrl;
  const _FilterBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: AppSpacing.s2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'filter_result'.tr,
              onTap: () => _showResultFilter(context),
            ),
            const SizedBox(width: AppSpacing.s2),
            _FilterChip(
              label: 'filter_date'.tr,
              onTap: () {
                showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                ).then((range) {
                  if (range != null) {
                    ctrl.setFilters(
                      from: '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}',
                      to: '${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}',
                    );
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResultFilter(BuildContext context) {
    final results = ['success', 'low_confidence', 'no_match', 'spoofing_detected', 'too_soon'];
    Get.dialog<void>(
      SimpleDialog(
        title: Text('filter_result'.tr),
        children: [
          SimpleDialogOption(
            child: Text('all'.tr),
            onPressed: () {
              Get.back<void>();
              ctrl.setFilters(result: null);
            },
          ),
          ...results.map((r) => SimpleDialogOption(
            child: Text('recognition_$r'.tr),
            onPressed: () {
              Get.back<void>();
              ctrl.setFilters(result: r);
            },
          )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
        decoration: BoxDecoration(
          border: Border.all(color: colors.borderHairline),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 13, color: colors.textSecondary)),
            const SizedBox(width: AppSpacing.s1),
            Icon(Icons.filter_list, size: 16, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final StationRecognitionLogModel log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final resultColor = _resultColor(log.result, colors);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s2),
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.employeeName ?? 'unknown'.tr,
                  style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.stationName} · ${log.verificationMethod}',
                  style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 11, color: colors.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.createdAt.year}-${log.createdAt.month.toString().padLeft(2, '0')}-${log.createdAt.day.toString().padLeft(2, '0')} ${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontFamily: 'Geist', fontSize: 11, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2, vertical: 2),
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  log.resultLabel.tr,
                  style: TextStyle(fontFamily: 'IBM Plex Sans Arabic', fontSize: 10, color: resultColor, fontWeight: FontWeight.w500),
                ),
              ),
              if (log.confidenceScore != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${(log.confidenceScore! * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontFamily: 'Geist', fontSize: 11, color: colors.textTertiary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _resultColor(String result, AppColorScheme colors) {
    switch (result) {
      case 'success': return colors.success;
      case 'low_confidence': return colors.warning;
      case 'no_match': return colors.error;
      case 'spoofing_detected': return colors.error;
      case 'too_soon': return colors.warning;
      default: return colors.textTertiary;
    }
  }
}

class _Pagination extends StatelessWidget {
  final RecognitionLogsController ctrl;
  const _Pagination({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final totalPages = (ctrl.total / ctrl.limit).ceil();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: ctrl.page > 1 ? () => ctrl.setPage(ctrl.page - 1) : null,
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
          Text(
            '${ctrl.page} / $totalPages',
            style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: colors.textSecondary),
          ),
          IconButton(
            onPressed: ctrl.page < totalPages ? () => ctrl.setPage(ctrl.page + 1) : null,
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
        ],
      ),
    );
  }
}
