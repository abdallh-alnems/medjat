import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../core/constant/theme/app_text_styles.dart';
import '../../../data/model/branch_model.dart';
import '../../../logic/controller/branch/branch_controller.dart';

/// Print-ready QR poster for a branch (PRD §5.1 — QR + GPS attendance).
///
/// Receives the branch via Get.arguments: either a `BranchModel` directly
/// (`{'branch': branch}`) or just a branch id (`{'branch_id': 5}`) — in the
/// latter case the screen resolves it from BranchController if available.
class BranchQrPosterScreen extends StatelessWidget {
  const BranchQrPosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final branch = _resolveBranch();

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
        actions: [
          if (hasQrCode)
            IconButton(
              tooltip: 'copy_qr_payload'.tr,
              icon: const Icon(Icons.content_copy, size: 20),
              onPressed: () => _copyPayload(branch.qrCode!),
            ),
        ],
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
                        ? _Poster(branch: branch)
                        : _MissingQrCard(branchName: branch.name),
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

  Future<void> _copyPayload(String payload) async {
    await Clipboard.setData(ClipboardData(text: payload));
    Get.snackbar('done'.tr, 'qr_payload_copied'.tr,
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
  const _MissingQrCard({required this.branchName});

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
