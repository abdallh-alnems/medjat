import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../logic/controller/auth/auth_controller.dart';

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

      final companyNameValue = companyName ??
          Get.find<AuthController>().user?.name ??
          'Medjat';

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
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
            pw.SizedBox(height: 20),
            _buildTable(headers, rows),
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
  ) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey400,
        width: 0.5,
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: headers
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
        ...rows.map(
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
