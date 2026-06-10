import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/model/attendance_model.dart';

class AttendancePdfExporter {
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
    required List<AttendanceRecordModel> records,
    required DateTime date,
  }) async {
    await _loadFonts();
    final bytes = await _buildPdf(records: records, date: date);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'attendance_${_fmtDate(date)}.pdf',
    );
  }

  static _Summary _computeSummary(List<AttendanceRecordModel> records) {
    final present =
        records.where((r) => r.status == 'present').length;
    final absent = records.where((r) => r.status == 'absent').length;
    final late = records.where((r) => (r.lateMinutes ?? 0) > 0).length;
    final leave = records
        .where((r) =>
            r.status == 'leave' ||
            r.status == 'holiday' ||
            r.status == 'weekly_off')
        .length;
    final notArrived =
        records.where((r) => r.status == 'not_arrived').length;
    final rate = records.isEmpty ? 0 : ((present / records.length) * 100).round();

    final lateRecords =
        records.where((r) => (r.lateMinutes ?? 0) > 0).toList();
    final avgLate = lateRecords.isEmpty
        ? 0
        : (lateRecords.fold<double>(0, (a, r) => a + (r.lateMinutes ?? 0)) /
                lateRecords.length)
            .round();

    return _Summary(
      present: present,
      absent: absent,
      late: late,
      leave: leave,
      notArrived: notArrived,
      rate: rate,
      avgLate: avgLate,
    );
  }

  static Future<Uint8List> _buildPdf({
    required List<AttendanceRecordModel> records,
    required DateTime date,
  }) async {
    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(base: _regular, bold: _bold);
    final summary = _computeSummary(records);
    final isRtl = (Get.locale?.languageCode ?? 'ar') == 'ar';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => _header(date),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          _summaryBlock(summary, records.length),
          pw.SizedBox(height: 14),
          _table(records, isRtl),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(DateTime date) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.6),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'attendance_report'.tr,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            _fmtDate(date),
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 6),
      child: pw.Text(
        '${ctx.pageNumber} / ${ctx.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  static pw.Widget _summaryBlock(_Summary s, int total) {
    pw.Widget cell(String label, String value, PdfColor color) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(value,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                )),
          ],
        ),
      );
    }

    return pw.GridView(
      crossAxisCount: 4,
      childAspectRatio: 2.4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        cell('attendance_rate'.tr, '${s.rate}%', PdfColors.green700),
        cell('avg_late_minutes'.tr,
            '${s.avgLate} ${"minutes_short".tr}', PdfColors.orange800),
        cell('present'.tr, '${s.present} / $total', PdfColors.blueGrey800),
        cell('absent'.tr, '${s.absent}', PdfColors.red700),
        cell('late'.tr, '${s.late}', PdfColors.orange700),
        cell('on_leave'.tr, '${s.leave}', PdfColors.amber700),
        cell('not_arrived'.tr, '${s.notArrived}', PdfColors.grey700),
        cell('total'.tr, '$total', PdfColors.black),
      ],
    );
  }

  static pw.Widget _table(List<AttendanceRecordModel> records, bool isRtl) {
    final headers = [
      '#',
      'name'.tr,
      'branch'.tr,
      'shift'.tr,
      'check_in_label'.tr,
      'check_out_label'.tr,
      'late_by'.tr,
      'overtime_by'.tr,
      'status'.tr,
      'notes'.tr,
    ];

    final rows = <List<String>>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      rows.add([
        '${i + 1}',
        r.employeeName ?? '-',
        r.branchName ?? '-',
        r.shiftName ?? '-',
        _fmtTime(r.checkIn),
        _fmtTime(r.checkOut),
        (r.lateMinutes ?? 0) > 0 ? '${r.lateMinutes!.round()}' : '-',
        (r.overtimeMinutes ?? 0) > 0 ? '${r.overtimeMinutes!.round()}' : '-',
        r.statusLabel,
        (r.note ?? '').trim().isEmpty ? '-' : r.note!.trim(),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      columnWidths: {
        0: const pw.FixedColumnWidth(20),
        4: const pw.FixedColumnWidth(45),
        5: const pw.FixedColumnWidth(45),
        6: const pw.FixedColumnWidth(35),
        7: const pw.FixedColumnWidth(35),
      },
    );
  }

  static String _fmtDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _fmtTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _Summary {
  final int present;
  final int absent;
  final int late;
  final int leave;
  final int notArrived;
  final int rate;
  final int avgLate;
  const _Summary({
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
    required this.notArrived,
    required this.rate,
    required this.avgLate,
  });
}
