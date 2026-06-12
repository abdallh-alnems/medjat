import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/model/payroll_model.dart';
import '../utils/currency.dart';
import '../utils/pdf_helpers.dart';

/// Renders a one-page payslip for a single employee and hands it to the
/// platform share sheet. The figures shown are whatever's on the model —
/// for live cycles that's the earned-to-date totals, for completed cycles
/// it's the saved snapshot.
class PayslipPdfExporter {
  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<void> _loadFonts() async {
    if (_regular != null && _bold != null) return;
    final reg = await rootBundle.load(
        'assets/fonts/IBMPlexSansArabic-Regular.ttf');
    final bold = await rootBundle.load(
        'assets/fonts/IBMPlexSansArabic-Bold.ttf');
    _regular = pw.Font.ttf(reg);
    _bold = pw.Font.ttf(bold);
  }

  static Future<void> exportAndShare({
    required PayrollModel payroll,
    String? branchName,
    String currencyIso = 'EGP',
  }) async {
    await _loadFonts();
    final bytes = await _buildPdf(
      payroll: payroll,
      branchName: branchName,
      currencyIso: currencyIso,
    );
    final safeName = (payroll.employeeName ?? 'employee')
        .replaceAll(RegExp(r'\s+'), '_');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'payslip_${safeName}_${payroll.year}_${payroll.month.toString().padLeft(2, '0')}.pdf',
    );
  }

  static String _money(double v) {
    final isNeg = v < 0;
    final s = v.abs().toStringAsFixed(2);
    // Group thousands on the integer part only.
    final dot = s.indexOf('.');
    final intPart = dot < 0 ? s : s.substring(0, dot);
    final frac = dot < 0 ? '' : s.substring(dot);
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${isNeg ? '−' : ''}${buf.toString()}$frac';
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<Uint8List> _buildPdf({
    required PayrollModel payroll,
    String? branchName,
    String currencyIso = 'EGP',
  }) async {
    final curSymbol = currencyLabel(currencyIso);
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: _regular!, bold: _bold!),
    );

    final companyName = pdfCompanyTitle();
    final cycleLabel =
        '${'month_${payroll.month}'.tr} ${payroll.year}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pdfTextDirection(),
        margin: const pw.EdgeInsets.fromLTRB(40, 50, 40, 40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header bar
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF0D7377),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'payslip_title'.tr,
                    style: pw.TextStyle(
                      fontSize: 20,
                      color: PdfColors.white,
                      font: _bold,
                    ),
                  ),
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                      font: _bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            // Identity block
            _kvRow('payslip_employee'.tr, payroll.employeeName ?? '—'),
            if (branchName != null && branchName.isNotEmpty)
              _kvRow('payslip_branch'.tr, branchName),
            _kvRow('payslip_cycle'.tr, cycleLabel),
            if (payroll.daysInCycle > 0)
              _kvRow(
                'payslip_days_worked'.tr,
                '${payroll.daysElapsed} / ${payroll.daysInCycle}',
              ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300, height: 1),
            pw.SizedBox(height: 16),
            // Figures table
            _figureRow('payslip_base_salary'.tr,
                _money(payroll.baseSalary), PdfColors.black),
            if ((payroll.daysInCycle > 0 &&
                payroll.daysElapsed < payroll.daysInCycle))
              _figureRow(
                'payslip_prorated_base'.tr,
                _money(_prorated(payroll)),
                PdfColors.grey700,
              ),
            _figureRow(
              'payslip_deductions'.tr,
              '− ${_money(payroll.totalDeductions)}',
              const PdfColor.fromInt(0xFFC0392B),
            ),
            _figureRow(
              'payslip_bonuses'.tr,
              '+ ${_money(payroll.totalBonuses)}',
              const PdfColor.fromInt(0xFF27AE60),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey400, height: 1),
            pw.SizedBox(height: 10),
            // Net pay — large
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'payslip_net'.tr,
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey700,
                    font: _regular,
                  ),
                ),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      _money(payroll.netSalary),
                      style: pw.TextStyle(
                        fontSize: 26,
                        font: _bold,
                        color: payroll.netSalary < 0
                            ? const PdfColor.fromInt(0xFFC0392B)
                            : const PdfColor.fromInt(0xFF0D7377),
                      ),
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      curSymbol,
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                        font: _regular,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300, height: 1),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${'payslip_generated_on'.tr}: ${_today()}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                    font: _regular,
                  ),
                ),
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                    font: _regular,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static double _prorated(PayrollModel p) {
    if (p.daysInCycle <= 0) return p.baseSalary;
    return p.baseSalary * p.daysElapsed / p.daysInCycle;
  }

  static pw.Widget _kvRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey700,
                font: _regular,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                font: _bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _figureRow(String label, String amount, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
              font: _regular,
            ),
          ),
          pw.Text(
            amount,
            style: pw.TextStyle(
              fontSize: 13,
              font: _bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
