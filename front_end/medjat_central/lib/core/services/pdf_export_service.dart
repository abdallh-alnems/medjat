import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/pdf_helpers.dart';

class PdfExportService {
  PdfExportService._();

  static pw.Font? _arabicFont;
  static pw.Font? _arabicFontBold;

  static Future<void> _initFonts() async {
    if (_arabicFont != null) return;
    final regular = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    );
    final bold = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Bold.ttf',
    );
    _arabicFont = pw.Font.ttf(regular);
    _arabicFontBold = pw.Font.ttf(bold);
  }

  static Future<void> exportReport({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
    String? companyName,
    String? subtitle,
  }) async {
    try {
      Get.snackbar(
        'exporting'.tr,
        '',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      await _initFonts();

      final doc = pw.Document(
        theme: pw.ThemeData.withFont(
          base: _arabicFont!,
          bold: _arabicFontBold!,
        ),
      );

      final companyNameValue = pdfCompanyTitle(companyName);

      final isRtl = pdfIsArabic();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection:
              isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            pw.Center(
              child: pw.Text(
                companyNameValue,
                style: pw.TextStyle(
                  font: _arabicFontBold,
                  fontSize: 16,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  font: _arabicFontBold,
                  fontSize: 20,
                ),
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                    font: _arabicFont,
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
            pw.SizedBox(height: 20),
            _buildTable(headers, rows, isRtl),
          ],
        ),
      );

      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${title.replaceAll(' ', '_')}.pdf',
      );

      Get.snackbar(
        'done'.tr,
        'export_success'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'error'.tr,
        'export_failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  static pw.Widget _buildTable(
    List<String> headers,
    List<List<String>> rows,
    bool isRtl,
  ) {
    // pw.Table renders columns in list order and does not flip them for RTL,
    // so reverse the columns ourselves to make the table read right-to-left.
    final orderedHeaders =
        isRtl ? headers.reversed.toList() : headers;
    final orderedRows = isRtl
        ? rows.map((r) => r.reversed.toList()).toList()
        : rows;

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 0.5,
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: orderedHeaders
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        font: _arabicFontBold,
                        fontSize: 10,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ))
              .toList(),
        ),
        ...orderedRows.map(
          (row) => pw.TableRow(
            children: row
                .map((cell) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        cell,
                        style: pw.TextStyle(
                          font: _arabicFont,
                          fontSize: 9,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
