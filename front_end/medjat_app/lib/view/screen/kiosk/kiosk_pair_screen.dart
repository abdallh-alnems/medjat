import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../logic/controller/station/station_controller.dart';

class KioskPairScreen extends StatefulWidget {
  const KioskPairScreen({super.key});

  @override
  State<KioskPairScreen> createState() => _KioskPairScreenState();
}

class _KioskPairScreenState extends State<KioskPairScreen> {
  final _codeController = TextEditingController();
  final _scannerController = MobileScannerController();
  bool _isLoading = false;
  bool _showScanner = false;
  bool _scannerDetected = false;

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    await Get.find<StationController>().activate(code);
    if (mounted) setState(() => _isLoading = false);
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_scannerDetected) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    _scannerDetected = true;
    _scannerController.stop();

    setState(() => _isLoading = true);
    Get.find<StationController>()
        .activate(barcode.rawValue!)
        .then((_) {
          if (mounted) setState(() => _isLoading = false);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفعيل الكيوسك'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back<void>(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: AppColors.brand(context),
            ),
            const SizedBox(height: 16),
            Text(
              'تفعيل وضع الكيوسك',
              style: AppTextStyles.h2(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'امسح رمز QR من لوحة الإدارة أو أدخل الرمز يدوياً',
              style: AppTextStyles.bodySecondary(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_showScanner)
              _buildScanner(context)
            else
              PrimaryButton(
                text: 'مسح رمز QR',
                isLoading: _isLoading,
                onPressed: _isLoading
                    ? () {}
                    : () => setState(() => _showScanner = true),
              ),
            const SizedBox(height: 16),
            Text(
              'أو أدخل الرمز يدوياً',
              style: AppTextStyles.sm(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'رمز التفعيل',
                border: OutlineInputBorder(),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'تفعيل',
              isLoading: _isLoading,
              onPressed: _isLoading ? () {} : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanner(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.of(context).borderHairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onBarcodeDetected,
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                _scannerController.stop();
                setState(() {
                  _showScanner = false;
                  _scannerDetected = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
