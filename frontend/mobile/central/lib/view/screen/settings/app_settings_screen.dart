import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constant/theme/theme.dart';
import '../../../core/constant/routes/app_routes.dart';
import '../../../core/services/locale_service.dart';
import '../../../core/services/dark_light_service.dart';
import '../../../core/widget/appearance_loading.dart';

/// A forward chevron that respects the current text direction (points left in
/// RTL, right in LTR) instead of being hard-coded.
Icon _forwardChevron(BuildContext context) {
  final isRtl = Directionality.of(context) == TextDirection.rtl;
  return Icon(
    isRtl ? Icons.chevron_left : Icons.chevron_right,
    size: 20,
    color: AppColors.of(context).textTertiary,
  );
}

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('app_settings'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.s4),
        children: [
          _AppSettingTile(
            icon: Icons.dark_mode_outlined,
            title: 'dark_mode'.tr,
            trailing: Obx(() {
              final mode = Get.find<DarkLightService>().mode;
              final label = mode == ThemeMode.system
                  ? 'theme_system'
                  : mode == ThemeMode.dark
                      ? 'theme_dark'
                      : 'theme_light';
              return Text(
                label.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.of(context).textSecondary,
                ),
              );
            }),
            onTap: () => _showThemeSheet(context),
          ),
          const SizedBox(height: AppSpacing.s2),
          _AppSettingTile(
            icon: Icons.language,
            title: 'language'.tr,
            trailing: Obx(() {
              final localeSvc = Get.find<LocaleService>();
              return Text(
                localeSvc.isArabic ? 'العربية' : 'English',
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.of(context).textSecondary,
                ),
              );
            }),
            onTap: () => _showLanguageSheet(context),
          ),
          const SizedBox(height: AppSpacing.s2),
          _AppSettingTile(
            icon: Icons.notifications_outlined,
            title: 'notifications'.tr,
            trailing: _forwardChevron(context),
            onTap: () => Get.toNamed<void>(AppRoutes.notificationPrefs),
          ),
          const SizedBox(height: AppSpacing.s6),
          const _VersionFooter(),
        ],
      ),
    );
  }
}

/// Plain app-version label shown at the bottom of the settings list.
class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        return Center(
          child: Text(
            'v${info.version}',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textTertiary,
            ),
          ),
        );
      },
    );
  }
}

void _showThemeSheet(BuildContext context) {
  final themeSvc = Get.find<DarkLightService>();
  final colors = AppColors.of(context);

  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s3),
              child: Text(
                'dark_mode'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const Divider(height: 1),
            _ThemeOption(
              label: 'theme_system'.tr,
              mode: ThemeMode.system,
              themeSvc: themeSvc,
              colors: colors,
            ),
            const Divider(height: 1),
            _ThemeOption(
              label: 'theme_light'.tr,
              mode: ThemeMode.light,
              themeSvc: themeSvc,
              colors: colors,
            ),
            const Divider(height: 1),
            _ThemeOption(
              label: 'theme_dark'.tr,
              mode: ThemeMode.dark,
              themeSvc: themeSvc,
              colors: colors,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final DarkLightService themeSvc;
  final AppColorScheme colors;

  const _ThemeOption({
    required this.label,
    required this.mode,
    required this.themeSvc,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = themeSvc.mode == mode;
      return ListTile(
        title: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: selected ? colors.brand : colors.textPrimary,
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_rounded, size: 22, color: colors.brand)
            : null,
        onTap: () {
          Navigator.pop(context);
          if (themeSvc.mode == mode) return;
          runWithAppearanceOverlay(() => themeSvc.setMode(mode));
        },
      );
    });
  }
}

void _showLanguageSheet(BuildContext context) {
  final localeSvc = Get.find<LocaleService>();
  final colors = AppColors.of(context);

  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s3),
              child: Text(
                'language'.tr,
                style: TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
            const Divider(height: 1),
            _LanguageOption(
              label: 'العربية',
              code: 'ar',
              localeSvc: localeSvc,
              colors: colors,
            ),
            const Divider(height: 1),
            _LanguageOption(
              label: 'English',
              code: 'en',
              localeSvc: localeSvc,
              colors: colors,
            ),
          ],
        ),
      ),
    ),
  );
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final String code;
  final LocaleService localeSvc;
  final AppColorScheme colors;

  const _LanguageOption({
    required this.label,
    required this.code,
    required this.localeSvc,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = localeSvc.locale.value.languageCode == code;
      return ListTile(
        title: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Sans Arabic',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: selected ? colors.brand : colors.textPrimary,
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_rounded, size: 22, color: colors.brand)
            : null,
        onTap: () {
          Navigator.pop(context);
          if (localeSvc.locale.value.languageCode == code) return;
          runWithAppearanceOverlay(() async => localeSvc.setLocale(code));
        },
      );
    });
  }
}

class _AppSettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const _AppSettingTile({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Sans Arabic',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else
              _forwardChevron(context),
          ],
        ),
      ),
    );
  }
}
