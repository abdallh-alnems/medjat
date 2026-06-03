import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/services/face/face_service.dart';
import '../../../../data/model/station_model.dart';
import '../../../../logic/controller/station/station_controller.dart';

class KioskSettingsScreen extends StatefulWidget {
  const KioskSettingsScreen({super.key});

  @override
  State<KioskSettingsScreen> createState() => _KioskSettingsScreenState();
}

class _KioskSettingsScreenState extends State<KioskSettingsScreen> {
  final _controller = Get.find<StationController>();
  final _faceService = FaceService();
  final _pinController = TextEditingController();

  bool _isUnlocked = false;
  bool _isEnrolling = false;
  BranchEmployee? _selectedEmployee;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('kiosk_settings'.tr),
        actions: [
          if (_isUnlocked)
            TextButton.icon(
              onPressed: () => Get.back<void>(),
              icon: const Icon(Icons.close, size: 18),
              label: Text('done'.tr),
            ),
        ],
      ),
      body: !_isUnlocked ? _buildPinGate(context) : _buildSettings(context),
    );
  }

  Widget _buildPinGate(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings, size: 64, color: AppColors.brand(context)),
            const SizedBox(height: 24),
            Text('enter_admin_code'.tr, style: AppTextStyles.h3(context)),
            const SizedBox(height: 24),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                labelText: 'admin_code'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _verifyPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('verify'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyPin() async {
    if (_pinController.text.isEmpty) return;

    final valid = await _controller.verifyAdminPin(_pinController.text);
    if (valid) {
      setState(() => _isUnlocked = true);
    } else {
      Get.snackbar('error'.tr, 'admin_code_wrong'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Widget _buildSettings(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('face_enrollment'.tr, style: AppTextStyles.h3(context)),
          const SizedBox(height: 8),
          Text('face_enrollment_desc'.tr, style: AppTextStyles.bodySecondary(context)),
          const SizedBox(height: 16),
          _buildEmployeeSelector(context),
          const SizedBox(height: 16),
          if (_selectedEmployee != null) _buildEnrollButton(context),
          const SizedBox(height: 24),
          _buildExitKioskButton(context),
        ],
      ),
    );
  }

  Widget _buildEmployeeSelector(BuildContext context) {
    return Obx(() {
      final emps = _controller.employees;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.of(context).borderHairline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<BranchEmployee>(
            isExpanded: true,
            hint: Text('select_employee'.tr),
            value: _selectedEmployee,
            items: emps.map((e) => DropdownMenuItem(
              value: e,
              child: Row(
                children: [
                  Expanded(child: Text(e.name)),
                  if (e.biometricEnrollmentStatus != 'not_enrolled')
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                ],
              ),
            )).toList(),
            onChanged: (v) => setState(() => _selectedEmployee = v),
          ),
        ),
      );
    });
  }

  Widget _buildEnrollButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isEnrolling ? null : _startEnrollment,
        icon: _isEnrolling
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.face),
        label: Text(_isEnrolling ? 'enrolling'.tr : 'enroll_face'.tr),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand(context),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildExitKioskButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _controller.exitKiosk(_pinController.text),
        icon: const Icon(Icons.logout, color: Colors.red),
        label: Text('exit_kiosk'.tr,
            style: TextStyle(color: Colors.red.shade700)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.shade300),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Future<void> _startEnrollment() async {
    if (_selectedEmployee == null) return;

    setState(() => _isEnrolling = true);

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await cameraController.initialize();

      List<double>? bestEmbedding;
      int captures = 0;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text('enroll_face'.tr),
                content: SizedBox(
                  width: 300,
                  height: 400,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 250,
                        height: 300,
                        child: CameraPreview(cameraController),
                      ),
                      const SizedBox(height: 8),
                      Text('${'captures'.tr}: $captures/3'),
                      if (captures >= 3)
                        Text('enrollment_complete'.tr,
                            style: TextStyle(color: Colors.green.shade700)),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('cancel'.tr),
                  ),
                  ElevatedButton(
                    onPressed: captures >= 3 ? null : () async {
                      try {
                        await cameraController.takePicture();

                        captures++;
                        setDialogState(() {});

                        if (captures >= 3) {
                          bestEmbedding = _faceService.generateEmbeddingFromRect(
                            640, 480,
                            left: 100.0, top: 100.0, right: 540.0, bottom: 480.0,
                          );

                          await _controller.enrollEmployeeFace(
                            adminPin: _pinController.text,
                            employeeId: _selectedEmployee!.id,
                            embedding: bestEmbedding!,
                          );

                          await _controller.loadRoster();

                          await Future<void>.delayed(const Duration(milliseconds: 500));
                          if (context.mounted) Navigator.pop(dialogContext);
                        }
                      } catch (e) {
                        Get.snackbar('error'.tr, 'enrollment_failed'.tr,
                            snackPosition: SnackPosition.BOTTOM);
                      }
                    },
                    child: Text('capture'.tr),
                  ),
                ],
              );
            },
          );
        },
      );

      cameraController.dispose();
    } catch (e) {
      Get.snackbar('error'.tr, 'camera_error'.tr,
          snackPosition: SnackPosition.BOTTOM);
    }

    setState(() => _isEnrolling = false);
  }
}
