import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/services/docx_export_service.dart';
import '../../../core/services/pdf_export_service.dart';

/// Shows a "PDF / Word" chooser, then exports the given report rows in the
/// picked format. Shared by every report screen so the export UX is identical.
Future<void> exportReportWithFormat(
  BuildContext context, {
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
  String? companyName,
  String? subtitle,
}) async {
  // Nothing to export — tell the user instead of producing an empty file.
  if (rows.isEmpty) {
    Get.snackbar(
      'no_report_data'.tr,
      '',
      snackPosition: SnackPosition.BOTTOM,
    );
    return;
  }

  // Capture the share anchor before any async gap (context may change after).
  final shareOrigin = _shareOrigin(context);

  final format = await showExportFormatSheet(context);
  if (format == 'pdf') {
    await PdfExportService.exportReport(
      title: title,
      headers: headers,
      rows: rows,
      companyName: companyName,
      subtitle: subtitle,
    );
  } else if (format == 'word') {
    await DocxExportService.exportReport(
      title: title,
      headers: headers,
      rows: rows,
      companyName: companyName,
      subtitle: subtitle,
      sharePositionOrigin: shareOrigin,
    );
  }
}

/// Shows the shared "PDF / Word" chooser and returns 'pdf', 'word', or null.
Future<String?> showExportFormatSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ExportFormatSheet(),
  );
}

/// "from — to" label for date-range reports, shown under the title in exports.
String reportPeriodLabel(DateTime start, DateTime end) {
  String f(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return '${f(start)}  —  ${f(end)}';
}

/// Anchor rect for the iOS/iPad share popover, derived from the screen. On
/// iPad share_plus throws without it; harmless elsewhere.
Rect? _shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

class _ExportFormatSheet extends StatelessWidget {
  const _ExportFormatSheet();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
              'export_as'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s3),
            _FormatTile(
              icon: Icons.picture_as_pdf_outlined,
              label: 'export_pdf'.tr,
              color: const Color(0xFFC0392B),
              colors: colors,
              onTap: () => Navigator.of(context).pop('pdf'),
            ),
            const SizedBox(height: AppSpacing.s2),
            _FormatTile(
              icon: Icons.description_outlined,
              label: 'export_word'.tr,
              color: const Color(0xFF2B579A),
              colors: colors,
              onTap: () => Navigator.of(context).pop('word'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final AppColorScheme colors;
  final VoidCallback onTap;

  const _FormatTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s4, vertical: AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.sunken,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.s3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
