import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../logic/controller/station/station_controller.dart';
import 'widgets/kiosk_app_bar.dart';

class KioskQrCheckInScreen extends StatefulWidget {
  const KioskQrCheckInScreen({super.key});

  @override
  State<KioskQrCheckInScreen> createState() => _KioskQrCheckInScreenState();
}

class _KioskQrCheckInScreenState extends State<KioskQrCheckInScreen> {
  final _controller = Get.find<StationController>();
  final _scannerController = MobileScannerController(
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const KioskAppBar(title: 'qr_checkin'),
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onQrDetected,
                  ),
                  _buildScanOverlay(context),
                  _buildInstructions(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOverlay(BuildContext context) {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.brand(context), width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'scan_employee_qr'.tr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    _isProcessing = true;

    await _scannerController.stop();

    final qrToken = barcode.rawValue!;

    await _controller.checkInOutQr(qrToken: qrToken);

    if (mounted) {
      await Future<void>.delayed(const Duration(seconds: 2));
      _isProcessing = false;
      _scannerController.start();
    }
  }
}
