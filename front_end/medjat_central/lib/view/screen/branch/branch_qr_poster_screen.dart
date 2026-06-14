import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../core/class/status_request.dart';
import '../../../data/model/branch_model.dart';
import '../../../data/data_source/remote/branch_data/branch_data.dart';
import '../../../logic/controller/branch/branch_controller.dart';
import '../../widget/branch/branch_location_sheet.dart';

/// Print-ready QR poster for a branch (PRD §5.1 — QR + GPS attendance).
///
/// Receives the branch via Get.arguments: either a `BranchModel` directly
/// (`{'branch': branch}`) or just a branch id (`{'branch_id': 5}`) — in the
/// latter case the screen resolves it from BranchController if available.
class BranchQrPosterScreen extends StatefulWidget {
  const BranchQrPosterScreen({super.key});

  @override
  State<BranchQrPosterScreen> createState() => _BranchQrPosterScreenState();
}

class _BranchQrPosterScreenState extends State<BranchQrPosterScreen> {
  final GlobalKey _posterKey = GlobalKey();
  BranchModel? _branch;
  bool _generating = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _branch = _resolveBranch();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final branch = _branch;

    if (branch == null) {
      return Scaffold(
        appBar: AppBar(title: Text('qr_poster_title'.tr)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s5),
            child: Text(
              'qr_branch_unavailable'.tr,
              style: AppTextStyles.bodySecondary(context),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final hasQrCode = branch.qrCode != null && branch.qrCode!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('qr_poster_title'.tr),
      ),
      backgroundColor: colors.sunken,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: hasQrCode
                        ? RepaintBoundary(
                            key: _posterKey,
                            child: _Poster(branch: branch),
                          )
                        : _MissingQrCard(
                            branchName: branch.name,
                            generating: _generating,
                            onGenerate: _generateQr,
                          ),
                  ),
                ),
              ),
              if (hasQrCode) ...[
                const SizedBox(height: AppSpacing.s3),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sharing ? null : _sharePoster,
                    icon: _sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.share_outlined, size: 18),
                    label: Text(
                      'share_qr'.tr,
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md)),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s3),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showBranchLocationSheet(
                    context,
                    branchId: branch.id,
                    branchName: branch.name,
                    initialLat: branch.lat,
                    initialLng: branch.lng,
                    initialRadius: branch.gpsRadiusMeters,
                    onSaved: (lat, lng, radius) {
                      setState(() {
                        _branch = branch.copyWith(
                            lat: lat, lng: lng, gpsRadiusMeters: radius);
                      });
                      if (Get.isRegistered<BranchController>()) {
          unawaited(Get.find<BranchController>().loadBranches());
                      }
                    },
                  ),
                  icon: const Icon(Icons.my_location, size: 18),
                  label: Text(
                    'set_branch_gps'.tr,
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Sans Arabic',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.brand,
                    side: BorderSide(color: colors.brand),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.s3),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s3),
              _PrintHint(),
            ],
          ),
        ),
      ),
    );
  }

  BranchModel? _resolveBranch() {
    final args = Get.arguments as Map<String, dynamic>?;
    if (args == null) return null;

    final passed = args['branch'];
    if (passed is BranchModel) return passed;

    final branchId = args['branch_id'] as int?;
    if (branchId == null) return null;

    if (Get.isRegistered<BranchController>()) {
      final ctrl = Get.find<BranchController>();
      for (final b in ctrl.branches) {
        if (b.id == branchId) return b;
      }
    }
    return null;
  }

  Future<void> _sharePoster() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _posterKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/branch_qr_${_branch?.id ?? 0}.png');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: _branch?.name,
        ),
      );
    } catch (_) {
      Get.snackbar('error'.tr, 'share_failed'.tr,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _generateQr() async {
    final branch = _branch;
    if (branch == null || _generating) return;
    setState(() => _generating = true);
    final res = await BranchData().generateBranchQr(branch.id);
    if (!mounted) return;
    setState(() => _generating = false);
    if (res['status'] == StatusRequest.success) {
      dynamic data = res['data'];
      if (data is Map && data['data'] is Map) data = data['data'];
      final code = data is Map ? data['qr_code'] as String? : null;
      if (code != null && code.isNotEmpty) {
        setState(() => _branch = branch.copyWith(qrCode: code));
        if (Get.isRegistered<BranchController>()) {
          unawaited(Get.find<BranchController>().loadBranches());
        }
        Get.snackbar('done'.tr, 'qr_generated'.tr,
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
    }
    Get.snackbar('error'.tr, 'qr_generate_failed'.tr,
        snackPosition: SnackPosition.BOTTOM);
  }
}

class _Poster extends StatelessWidget {
  final BranchModel branch;
  const _Poster({required this.branch});

  @override
  Widget build(BuildContext context) {
    // White poster on a colored background so screenshots crop cleanly
    // for printing. Sized to feel A5-ish on phone screens; users print
    // via OS share/screenshot.
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'qr_poster_heading'.tr,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            branch.name,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
          ),
          if (branch.address != null && branch.address!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              branch.address!,
              style: const TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.s5),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: QrImageView(
              data: branch.qrCode!,
              size: 240,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'qr_poster_instruction'.tr,
            style: const TextStyle(
              fontFamily: 'IBM Plex Sans Arabic',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF111827),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s3),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s3, vertical: AppSpacing.s2),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.my_location,
                    size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Text(
                  'qr_poster_gps_radius'.trParams(
                      {'meters': branch.gpsRadiusMeters.toString()}),
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 11,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            branch.qrCode!,
            style: const TextStyle(
              fontFamily: 'Geist',
              fontSize: 11,
              letterSpacing: 1.5,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingQrCard extends StatelessWidget {
  final String branchName;
  final bool generating;
  final VoidCallback onGenerate;
  const _MissingQrCard({
    required this.branchName,
    required this.generating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2_outlined, size: 56, color: colors.textTertiary),
          const SizedBox(height: AppSpacing.s3),
          Text(branchName, style: AppTextStyles.h3(context)),
          const SizedBox(height: AppSpacing.s2),
          Text(
            'qr_not_generated_yet'.tr,
            style: AppTextStyles.bodySecondary(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: generating ? null : onGenerate,
              icon: generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.qr_code_2, size: 18),
              label: Text(
                'generate_qr_now'.tr,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrintHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.brandSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.brand.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.print_outlined, size: 18, color: colors.brand),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Text(
              'qr_print_hint'.tr,
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 12,
                color: colors.brand,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
