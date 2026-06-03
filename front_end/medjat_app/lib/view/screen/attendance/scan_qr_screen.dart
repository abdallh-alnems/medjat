import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../logic/controller/attendance/attendance_controller.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _hasScanned = false;
  bool _flashOn = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    _hasScanned = true;
    HapticFeedback.mediumImpact();
    _scannerController.stop();

    final controller = Get.find<AttendanceController>();
    controller.processQrScan(barcode.rawValue!);
  }

  void _showErrorSheet(String message) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ErrorBottomSheet(
        message: message,
        onRetry: () {
          Navigator.pop(context);
          _hasScanned = false;
          _scannerController.start();
          Get.find<AttendanceController>().reset();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final colors = isLight ? AppColors.light : AppColors.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('scan_qr'.tr),
        elevation: 0,
      ),
      body: GetBuilder<AttendanceController>(
        builder: (controller) {
          if (controller.status == StatusRequest.failure &&
              controller.errorMessage != null &&
              _hasScanned) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showErrorSheet(controller.errorMessage!);
            });
          }

          return Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
              ),
              _buildScanOverlay(colors),
              if (controller.isProcessing) _buildLoadingOverlay(),
              _buildFlashToggle(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScanOverlay(AppColorScheme colors) {
    final size = MediaQuery.of(context).size;
    final scanSize = size.width * 0.7;
    final scanTop = (size.height - scanSize) / 2 - 40;
    final scanLeft = (size.width - scanSize) / 2;

    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
              ),
              Positioned(
                top: scanTop,
                left: scanLeft,
                child: Container(
                  width: scanSize,
                  height: scanSize,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: scanTop,
          left: scanLeft,
          child: CustomPaint(
            size: Size(scanSize, scanSize),
            painter: _ScanFramePainter(colors.brand),
          ),
        ),
        Positioned(
          top: scanTop + scanSize + AppSpacing.s5,
          left: 0,
          right: 0,
          child: Text(
            'point_camera_qr'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTextStyles.arabicFamily,
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'registering'.tr,
              style: const TextStyle(
                fontFamily: AppTextStyles.arabicFamily,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashToggle() {
    return Positioned(
      bottom: 48,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            setState(() => _flashOn = !_flashOn);
            _scannerController.toggleTorch();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s4,
              vertical: AppSpacing.s2,
            ),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _flashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s2),
                const Text(
                  'Flash',
                  style: TextStyle(
                    fontFamily: AppTextStyles.latinFamily,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final Color color;
  _ScanFramePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerLength = 30.0;
    const radius = 16.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(radius),
    );

    final path = Path();
    path.addRRect(rrect);
    canvas.drawPath(path, paint..strokeWidth = 1);

    paint.strokeWidth = 4;
    final corners = [
      [Offset.zero, const Offset(cornerLength, 0), const Offset(0, cornerLength)],
      [
        Offset(size.width, 0),
        Offset(size.width - cornerLength, 0),
        Offset(size.width, cornerLength),
      ],
      [
        Offset(0, size.height),
        Offset(cornerLength, size.height),
        Offset(0, size.height - cornerLength),
      ],
      [
        Offset(size.width, size.height),
        Offset(size.width - cornerLength, size.height),
        Offset(size.width, size.height - cornerLength),
      ],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[1], corner[0], paint);
      canvas.drawLine(corner[2], corner[0], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorBottomSheet extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBottomSheet({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.all(AppSpacing.s4),
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.error.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.close, size: 28, color: colors.error),
          ),
          const SizedBox(height: AppSpacing.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTextStyles.arabicFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s5),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Get.back<void>();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textSecondary,
                    side: BorderSide(color: colors.borderStrong),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text('back'.tr),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text('retry'.tr),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
