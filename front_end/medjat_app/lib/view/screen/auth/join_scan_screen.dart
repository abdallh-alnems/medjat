import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/services/deep_link_service.dart';
import '../../../logic/controller/auth/auth_controller.dart';

/// Scan the join QR shown by the company admin. The QR encodes the same join
/// URL as the link, so we extract the token and activate — no phone or code
/// typing needed.
class JoinScanScreen extends StatefulWidget {
  const JoinScanScreen({super.key});

  @override
  State<JoinScanScreen> createState() => _JoinScanScreenState();
}

class _JoinScanScreenState extends State<JoinScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final token = tokenFromScannedValue(raw);
    if (token == null) return;

    _handled = true;
    HapticFeedback.mediumImpact();
    await _scannerController.stop();

    final ok = await Get.find<AuthController>().activateWithToken(token);
    if (!ok && mounted) {
      // Activation failed (expired/used); let the user try another code.
      _handled = false;
      await _scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('scan_join_title'.tr),
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Text(
              'scan_join_hint'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
