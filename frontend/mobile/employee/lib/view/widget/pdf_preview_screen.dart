import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';

/// In-app PDF reader. Renders the downloaded bytes inside the app (no external
/// viewer) using the platform's native PDF renderer.
///
/// When [filePath] points at a copy of the same PDF on disk, an extra action
/// hands that file to another app — the employee can still save or share a
/// payslip, but reading it never depends on a PDF reader being installed.
class PdfPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String? title;
  final String? filePath;
  const PdfPreviewScreen({
    super.key,
    required this.bytes,
    this.title,
    this.filePath,
  });

  Future<void> _openExternally() async {
    final result = await OpenFilex.open(filePath!, type: 'application/pdf');
    if (result.type != ResultType.done) {
      Get.snackbar(
        'error'.tr,
        result.type == ResultType.noAppToOpen
            ? 'no_pdf_viewer_app'.tr
            : 'failed_open_file'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (title != null && title!.isNotEmpty) ? title! : 'view_document'.tr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (filePath != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'open_in_another_app'.tr,
              onPressed: _openExternally,
            ),
        ],
      ),
      body: PDFView(
        pdfData: bytes,
        onError: (error) {
          Get.snackbar('error'.tr, 'document_open_failed'.tr,
              snackPosition: SnackPosition.BOTTOM);
        },
      ),
    );
  }
}
