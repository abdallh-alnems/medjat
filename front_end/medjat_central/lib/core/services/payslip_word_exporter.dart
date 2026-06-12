import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/model/payroll_model.dart';
import '../utils/currency.dart';
import '../utils/pdf_helpers.dart';

/// Word (HTML-as-.doc) counterpart of [PayslipPdfExporter]. Produces a real,
/// editable, shareable payslip file that opens in Microsoft Word and follows
/// the app language direction (Arabic RTL / English LTR).
class PayslipWordExporter {
  PayslipWordExporter._();

  static Future<void> exportAndShare({
    required PayrollModel payroll,
    String? branchName,
    String currencyIso = 'EGP',
    Rect? sharePositionOrigin,
  }) async {
    final html = _buildHtml(
      payroll: payroll,
      branchName: branchName,
      currencyIso: currencyIso,
    );
    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(html)];

    final dir = await getTemporaryDirectory();
    final safeName =
        (payroll.employeeName ?? 'employee').replaceAll(RegExp(r'\s+'), '_');
    final file = File(
        '${dir.path}/payslip_${safeName}_${payroll.year}_${payroll.month.toString().padLeft(2, '0')}.doc');
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: 'payslip_title'.tr,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  static double _prorated(PayrollModel p) {
    if (p.daysInCycle <= 0) return p.baseSalary;
    return p.baseSalary * p.daysElapsed / p.daysInCycle;
  }

  static String _money(double v) {
    final isNeg = v < 0;
    final s = v.abs().toStringAsFixed(2);
    final dot = s.indexOf('.');
    final intPart = dot < 0 ? s : s.substring(0, dot);
    final frac = dot < 0 ? '' : s.substring(dot);
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${isNeg ? '−' : ''}$buf$frac';
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _buildHtml({
    required PayrollModel payroll,
    String? branchName,
    required String currencyIso,
  }) {
    final dir = pdfIsArabic() ? 'rtl' : 'ltr';
    final company = pdfCompanyTitle();
    final cur = currencyLabel(currencyIso);
    final cycleLabel = '${'month_${payroll.month}'.tr} ${payroll.year}';

    final showProrated = payroll.daysInCycle > 0 &&
        payroll.daysElapsed < payroll.daysInCycle;

    String kv(String label, String value) =>
        '<tr><td class="k">${_esc(label)}</td><td class="v">${_esc(value)}</td></tr>';

    String figure(String label, String amount, String color) =>
        '<tr><td class="fl">${_esc(label)}</td><td class="fv" style="color:$color">${_esc(amount)}</td></tr>';

    final netColor = payroll.netSalary < 0 ? '#C0392B' : '#0D7377';

    return '''
<html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:w="urn:schemas-microsoft-com:office:word" xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta charset="utf-8">
<title>${_esc('payslip_title'.tr)}</title>
<style>
  body { font-family: 'IBM Plex Sans Arabic', Arial, sans-serif; direction: $dir; }
  .bar { background-color: #0D7377; color: #ffffff; padding: 12px 16px; border-radius: 8px;
         display: flex; justify-content: space-between; }
  .bar .t { font-size: 18pt; font-weight: bold; }
  .bar .c { font-size: 12pt; font-weight: bold; }
  table { width: 100%; border-collapse: collapse; direction: $dir; margin-top: 16pt; }
  td { padding: 5px 0; font-size: 11pt; }
  td.k { color: #666666; width: 35%; }
  td.v { font-weight: bold; }
  td.fl { color: #666666; }
  td.fv { font-weight: bold; text-align: ${dir == 'rtl' ? 'left' : 'right'}; }
  .net { margin-top: 14pt; padding-top: 10pt; border-top: 2px solid #cccccc;
         display: flex; justify-content: space-between; align-items: baseline; }
  .net .l { font-size: 12pt; color: #666666; }
  .net .a { font-size: 22pt; font-weight: bold; color: $netColor; }
  .foot { margin-top: 24pt; padding-top: 6pt; border-top: 1px solid #dddddd;
          color: #888888; font-size: 9pt; display: flex; justify-content: space-between; }
</style>
</head>
<body>
  <div class="bar"><span class="t">${_esc('payslip_title'.tr)}</span><span class="c">${_esc(company)}</span></div>
  <table>
    ${kv('payslip_employee'.tr, payroll.employeeName ?? '—')}
    ${(branchName != null && branchName.isNotEmpty) ? kv('payslip_branch'.tr, branchName) : ''}
    ${kv('payslip_cycle'.tr, cycleLabel)}
    ${payroll.daysInCycle > 0 ? kv('payslip_days_worked'.tr, '${payroll.daysElapsed} / ${payroll.daysInCycle}') : ''}
  </table>
  <table>
    ${figure('payslip_base_salary'.tr, _money(payroll.baseSalary), '#000000')}
    ${showProrated ? figure('payslip_prorated_base'.tr, _money(_prorated(payroll)), '#666666') : ''}
    ${figure('payslip_deductions'.tr, '− ${_money(payroll.totalDeductions)}', '#C0392B')}
    ${figure('payslip_bonuses'.tr, '+ ${_money(payroll.totalBonuses)}', '#27AE60')}
  </table>
  <div class="net"><span class="l">${_esc('payslip_net'.tr)}</span><span class="a">${_esc(_money(payroll.netSalary))} ${_esc(cur)}</span></div>
  <div class="foot"><span>${_esc('payslip_generated_on'.tr)}: ${_today()}</span><span>${_esc(company)}</span></div>
</body>
</html>''';
  }
}
