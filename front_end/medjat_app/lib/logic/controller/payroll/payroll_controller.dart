import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/class/status_request.dart';
import '../../../data/data_source/remote/payroll_data/payroll_data.dart';
import '../../../view/widget/pdf_preview_screen.dart';

class PayrollController extends GetxController {
  final PayrollData _payrollData = Get.find<PayrollData>();

  StatusRequest status = StatusRequest.none;
  Map<String, dynamic>? slipData;
  String selectedMonth = '';

  /// The current calendar month in `YYYY-MM` format.
  String get _currentMonth {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Whether the employee can move forward a month. Future months haven't
  /// happened yet, so navigating past the current month is not allowed.
  bool get canGoNext => selectedMonth.compareTo(_currentMonth) < 0;

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    selectedMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    loadSlip(selectedMonth);
  }

  void changeMonth(String month) {
    selectedMonth = month;
    loadSlip(month);
  }

  Future<void> loadSlip(String month) async {
    status = StatusRequest.loading;
    update();

    final response = await _payrollData.getSlip(month);
    final responseStatus = response['status'] as StatusRequest?;

    if (responseStatus == StatusRequest.success) {
      slipData = response['data'] as Map<String, dynamic>?;
      status = StatusRequest.success;
    } else if (response['statusCode'] == 404) {
      // No payroll slip generated for this month yet — show the friendly
      // "no slip this month" empty state instead of the generic error screen.
      slipData = null;
      status = StatusRequest.success;
    } else if (responseStatus == StatusRequest.offline) {
      status = StatusRequest.offline;
    } else {
      status = StatusRequest.failure;
    }

    update();
  }

  /// A payslip download in flight. Keeps the button in a spinner state and
  /// blocks a second tap while the PDF is being fetched.
  bool isDownloadingPdf = false;

  Future<void> downloadPdf() async {
    if (isDownloadingPdf) return;
    isDownloadingPdf = true;
    update();

    try {
      final response = await _payrollData.getSlipPdf(selectedMonth);
      final bytes = response['bytes'];

      if (response['status'] != StatusRequest.success || bytes is! List<int>) {
        _downloadFailed(
          response['status'] == StatusRequest.offline
              ? 'no_internet'.tr
              : response['statusCode'] == 404
                  ? 'no_slip_month'.tr
                  : 'failed_download_slip'.tr,
        );
        return;
      }

      // Only a real PDF may be written under a .pdf name. If the server ever
      // answers with JSON or an error page (HTTP 200 all the same), saving and
      // opening it makes the device's PDF viewer pop "the current document
      // format is not pdf" — an error the employee cannot act on. Fail with a
      // clear message instead.
      final pdf = _extractPdf(bytes);
      if (pdf == null) {
        _downloadFailed('failed_download_slip'.tr);
        return;
      }

      // The temp copy only backs the viewer's "open in another app" action, so
      // a failure to write it must not stop the employee from reading the
      // slip — the preview renders from the bytes either way.
      String? filePath;
      try {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/payslip_$selectedMonth.pdf');
        await file.writeAsBytes(pdf, flush: true);
        filePath = file.path;
      } catch (_) {
        filePath = null;
      }

      // Read in-app rather than handing the file straight to the device's PDF
      // reader: a phone with no reader installed used to hit a dead end here.
      unawaited(Get.to<void>(() => PdfPreviewScreen(
            bytes: Uint8List.fromList(pdf),
            title: '${'my_salary'.tr} $selectedMonth',
            filePath: filePath,
          )));
    } catch (e) {
      _downloadFailed('failed_download_slip'.tr);
    } finally {
      isDownloadingPdf = false;
      update();
    }
  }

  void _downloadFailed(String message) {
    Get.snackbar('error'.tr, message);
  }

  /// Returns the payload as a valid PDF, or `null` when it isn't one.
  ///
  /// The `%PDF-` signature must appear within the first kilobyte. Anything
  /// printed before it (a PHP warning leaking into a binary response is the
  /// classic case) is dropped: the file offsets inside a PDF are measured from
  /// its header, so trimming the noise off the front restores a readable file
  /// instead of one every viewer rejects.
  @visibleForTesting
  static List<int>? extractPdf(List<int> bytes) => _extractPdf(bytes);

  static List<int>? _extractPdf(List<int> bytes) {
    const signature = [0x25, 0x50, 0x44, 0x46, 0x2D]; // %PDF-
    final limit = bytes.length < 1024 ? bytes.length : 1024;
    for (var i = 0; i + signature.length <= limit; i++) {
      var matched = true;
      for (var j = 0; j < signature.length; j++) {
        if (bytes[i + j] != signature[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return i == 0 ? bytes : bytes.sublist(i);
    }
    return null;
  }
}
