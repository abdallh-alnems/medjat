import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:get/get.dart';

/// In-app PDF reader. Renders the downloaded bytes inside the app (no external
/// viewer) using the platform's native PDF renderer.
class PdfPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String? title;
  const PdfPreviewScreen({super.key, required this.bytes, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (title != null && title!.isNotEmpty) ? title! : 'view_document'.tr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
