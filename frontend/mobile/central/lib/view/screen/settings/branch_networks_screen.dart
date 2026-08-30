import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/class/status_request.dart';
import '../../../core/constant/theme/app_colors.dart';
import '../../../core/constant/theme/app_spacing.dart';
import '../../../logic/controller/settings/branch_networks_controller.dart';

/// Approval screen for a branch's WiFi access points.
///
/// The coverage figure is the reason this screen exists: it answers "if I
/// approve exactly these and switch to enforcing, what share of last week's
/// check-ins would still pass?" before the switch is flipped.
class BranchNetworksScreen extends StatelessWidget {
  const BranchNetworksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text('wifi_networks'.tr)),
      body: GetBuilder<BranchNetworksController>(
        builder: (c) {
          if (c.status == StatusRequest.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.s4),
            children: [
              Text(
                c.branchName,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                'wifi_networks_hint'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 12,
                  color: colors.textTertiary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),

              _ModeSelector(ctrl: c),
              const SizedBox(height: AppSpacing.s4),

              Text(
                'wifi_seen_networks'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s2),

              if (c.networks.isEmpty)
                Text(
                  'wifi_no_sightings'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 12,
                    color: colors.textTertiary,
                    height: 1.5,
                  ),
                )
              else
                ...c.networks.map((n) => _NetworkTile(ctrl: c, network: n)),

              if (c.totalSightings > 0) ...[
                const SizedBox(height: AppSpacing.s4),
                _CoverageCard(ctrl: c),
              ],

              const SizedBox(height: AppSpacing.s5),
              ElevatedButton(
                onPressed: (c.willEnforce && c.selected.isEmpty)
                    ? null
                    : () async {
                        final ok = await c.save();
                        Get.snackbar(
                          ok ? 'done'.tr : 'error'.tr,
                          ok ? 'config_saved'.tr : 'config_save_failed'.tr,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                child: Text(c.willEnforce
                    ? 'wifi_save_and_enforce'.tr
                    : 'wifi_save_selection'.tr),
              ),
              if (c.willEnforce && c.selected.isEmpty) ...[
                const SizedBox(height: AppSpacing.s2),
                Text(
                  'wifi_needs_one_network'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 11,
                    color: colors.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s4),
            ],
          );
        },
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final BranchNetworksController ctrl;
  const _ModeSelector({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'wifi_mode'.tr,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        for (final entry in const {
          'learning': 'wifi_mode_learning',
          'enforcing': 'wifi_mode_enforcing',
          'optional': 'wifi_mode_optional',
        }.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s2),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: () => ctrl.setMode(entry.key),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.s3),
                decoration: BoxDecoration(
                  color: ctrl.mode == entry.key
                      ? colors.brandSubtle
                      : colors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: ctrl.mode == entry.key
                        ? colors.brand
                        : colors.borderHairline,
                    width: ctrl.mode == entry.key ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      ctrl.mode == entry.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: ctrl.mode == entry.key
                          ? colors.brand
                          : colors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.s3),
                    Expanded(
                      child: Text(
                        entry.value.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 13,
                          fontWeight: ctrl.mode == entry.key
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: ctrl.mode == entry.key
                              ? colors.brand
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Text(
          'wifi_mode_hint'.tr,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 11,
            color: colors.textTertiary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _NetworkTile extends StatelessWidget {
  final BranchNetworksController ctrl;
  final BranchNetworkSighting network;
  const _NetworkTile({required this.ctrl, required this.network});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final checked = ctrl.selected.contains(network.bssid);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => ctrl.toggle(network.bssid),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.s3),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: checked ? colors.brand : colors.borderHairline,
              width: checked ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: checked ? colors.brand : colors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      network.ssid ?? network.bssid,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      network.bssid,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'wifi_sightings_count'
                              .trParams({'count': '${network.sightings}'}),
                          style: TextStyle(
                            fontFamily: 'IBM Plex Sans Arabic',
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        _LocationBadge(network: network),
                      ],
                    ),
                    // A network only ever seen from outside the geofence is
                    // almost always an employee's home router.
                    if (network.allOutside) ...[
                      const SizedBox(height: 4),
                      Text(
                        'wifi_outside_hint'.tr,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Sans Arabic',
                          fontSize: 11,
                          color: colors.error,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationBadge extends StatelessWidget {
  final BranchNetworkSighting network;
  const _LocationBadge({required this.network});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isGood = network.allInside;
    final isBad = network.allOutside;

    final label = isGood
        ? 'wifi_all_inside'.tr
        : isBad
            ? 'wifi_all_outside'.tr
            : 'wifi_mixed_location'.trParams({
                'inside': '${network.insideCount}',
                'outside': '${network.outsideCount}',
              });

    final color = isGood
        ? colors.brand
        : isBad
            ? colors.error
            : colors.textSecondary;

    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s2, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  final BranchNetworksController ctrl;
  const _CoverageCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final low = ctrl.isLowCoverage;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: low ? colors.error.withValues(alpha: 0.08) : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: low ? colors.error : colors.borderHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'wifi_coverage'.tr,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Sans Arabic',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${ctrl.coveragePercent.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: low ? colors.error : colors.brand,
                ),
              ),
            ],
          ),
          if (low) ...[
            const SizedBox(height: 4),
            Text(
              'wifi_coverage_warning'.trParams({
                'percent': (100 - ctrl.coveragePercent).toStringAsFixed(1),
              }),
              style: TextStyle(
                fontFamily: 'IBM Plex Sans Arabic',
                fontSize: 11,
                color: colors.error,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
