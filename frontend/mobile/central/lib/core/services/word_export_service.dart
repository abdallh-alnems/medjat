import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/pdf_helpers.dart';

/// Exports a report as a real, shareable Word file.
///
/// The file is a Word-flavoured HTML document saved with a `.doc` extension —
/// Microsoft Word (and Google Docs, LibreOffice…) open and edit it natively,
/// and it can be sent to anyone via the platform share sheet. HTML tables
/// honour `dir="rtl"`, so Arabic reports read right-to-left automatically.
class WordExportService {
  WordExportService._();

  static Future<void> exportReport({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    String? companyName,
    String? subtitle,
    Rect? sharePositionOrigin,
  }) async {
    try {
      Get.snackbar(
        'exporting'.tr,
        '',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      final isRtl = pdfIsArabic();
      final company = pdfCompanyTitle(companyName);
      final html = _buildHtml(
        title: title,
        company: company,
        subtitle: subtitle,
        headers: headers,
        rows: rows,
        isRtl: isRtl,
      );

      // Prepend a UTF-8 BOM so Word detects the encoding and renders Arabic.
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(html)];

      final dir = await getTemporaryDirectory();
      final safeName = title.replaceAll(RegExp(r'\s+'), '_');
      final file = File('${dir.path}/$safeName.doc');
      await file.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          title: title,
          // Required so the iPad share popover has an anchor (else it throws).
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      Get.snackbar(
        'done'.tr,
        'export_success'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'error'.tr,
        'export_failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _buildHtml({
    required String title,
    required String company,
    String? subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    required bool isRtl,
  }) {
    final dir = isRtl ? 'rtl' : 'ltr';
    final th = headers.map((h) => '<th>${_esc(h)}</th>').join();
    final body = rows
        .map((r) => '<tr>${r.map((c) => '<td>${_esc(c)}</td>').join()}</tr>')
        .join();
    final subtitleHtml = (subtitle != null && subtitle.isNotEmpty)
        ? '<div class="subtitle">${_esc(subtitle)}</div>'
        : '';

    return '''
<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta charset="utf-8">
<title>${_esc(title)}</title>
<style>
  body { font-family: 'IBM Plex Sans Arabic', Arial, sans-serif; direction: $dir; }
  .company { text-align: center; font-size: 14pt; font-weight: bold; margin-bottom: 4pt; }
  h1 { text-align: center; font-size: 20pt; margin: 0 0 4pt; }
  .subtitle { text-align: center; font-size: 11pt; color: #555555; margin-bottom: 16pt; }
  table { border-collapse: collapse; width: 100%; direction: $dir; }
  th, td { border: 1px solid #999999; padding: 6px; font-size: 10pt; text-align: center; }
  th { background-color: #e8e8e8; font-weight: bold; }
</style>
</head>
<body>
  <div class="company">${_esc(company)}</div>
  <h1>${_esc(title)}</h1>
  $subtitleHtml
  <table dir="$dir">
    <thead><tr>$th</tr></thead>
    <tbody>$body</tbody>
  </table>
</body>
</html>''';
  }
}
