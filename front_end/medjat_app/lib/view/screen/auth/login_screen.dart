import 'dart:ui' as ui;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../../core/class/status_request.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/constant/routes/app_routes.dart';
import '../../../../core/services/locale_service.dart';
import '../../../../core/shared/buttons/primary_button.dart';
import '../../../../core/shared/input_fields/primary_input.dart';
import '../../../../logic/controller/auth/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late Country _country;

  @override
  void initState() {
    super.initState();
    _country = _defaultCountry();
  }

  Country _defaultCountry() {
    final code = ui.PlatformDispatcher.instance.locale.countryCode;
    if (code != null && code.isNotEmpty) {
      try {
        return CountryService().findByCode(code) ?? _egypt();
      } catch (_) {}
    }
    return _egypt();
  }

  Country _egypt() => CountryService().findByCode('EG')!;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      onSelect: (c) => setState(() => _country = c),
    );
  }

  void _submit(AuthController controller) {
    if (_formKey.currentState!.validate()) {
      final national = _phoneController.text.trim();
      final phoneE164 = '+${_country.phoneCode}$national';
      controller.login(phone: phoneE164, code: _codeController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: GestureDetector(
                        onTap: () => Get.find<LocaleService>().toggleLocale(),
                        child: Obx(() {
                          final localeSvc = Get.find<LocaleService>();
                          return Text(
                            localeSvc.isArabic ? 'English' : 'العربية',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: AppColors.brand(context),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  Text(
                    'login'.tr,
                    style: AppTextStyles.h2(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'login_hint'.tr,
                    style: AppTextStyles.bodySecondary(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _CountryPhoneField(
                    controller: _phoneController,
                    country: _country,
                    onPickCountry: _pickCountry,
                  ),
                  const SizedBox(height: 16),
                  PrimaryInput(
                    label: 'activation_code'.tr,
                    controller: _codeController,
                    keyboardType: TextInputType.text,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'required'.tr;
                      if (v.trim().length < 4) return 'code_too_short'.tr;
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  GetBuilder<AuthController>(
                    builder: (_) {
                      final isLoading =
                          controller.status.value == StatusRequest.loading;
                      return PrimaryButton(
                        text: 'login'.tr,
                        isLoading: isLoading,
                        onPressed: isLoading
                            ? () {}
                            : () => _submit(controller),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Get.toNamed<void>(AppRoutes.joinScan),
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: Text('scan_join_qr'.tr),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Get.toNamed<void>(AppRoutes.kioskPair),
                    child: Text(
                      'kiosk_mode'.tr,
                      style: TextStyle(color: AppColors.brand(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final Country country;
  final VoidCallback onPickCountry;

  const _CountryPhoneField({
    required this.controller,
    required this.country,
    required this.onPickCountry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'phone_number'.tr,
            style: AppTextStyles.bodySecondary(context),
          ),
        ),
        IntrinsicHeight(
          child: Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onPickCountry,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${country.flagEmoji}  +${country.phoneCode}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(14),
                  ],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = (v ?? '').trim();
                    if (n.isEmpty) return 'required'.tr;
                    final full = '${country.phoneCode}$n';
                    if (full.length < 8 || full.length > 15) {
                      return 'invalid_phone'.tr;
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
