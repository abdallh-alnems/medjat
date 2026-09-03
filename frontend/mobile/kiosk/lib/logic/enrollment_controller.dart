import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permedjat_shared/permedjat_shared.dart';

import '../core/api/kiosk_api.dart';
import '../core/kiosk_lock.dart';
import '../core/network/kiosk_crud.dart';
import 'kiosk_controller.dart';

enum AdminPhase {
  /// Typing the access code generated in the management app.
  locked,

  /// The branch roster, unenrolled first.
  roster,

  /// Camera up for the selected employee.
  capturing,

  /// Server is judging the capture.
  saving,

  /// Result of the last enrollment.
  result,
}

/// Drives the kiosk's administration area: unlock, list, enrol, close.
///
/// This is the highest-privilege surface on the tablet — it writes the face
/// data that identification will later trust — so two properties matter more
/// than convenience:
///
///  * It opens only against a single-use code generated in the management app.
///    There is no static PIN; a static PIN is shared once and works forever.
///  * It closes itself. An enrollment screen left open on a wall is a
///    self-enrollment machine, and the person who walked away is exactly the
///    person who will not notice.
class EnrollmentController extends GetxController {
  EnrollmentController({KioskCrud? crud}) : _crud = crud ?? KioskCrud();

  final KioskCrud _crud;
  final KioskController _kiosk = Get.find<KioskController>();

  /// Matches the server's session TTL. Refreshed by every successful call, so a
  /// supervisor working through a queue is never interrupted mid-enrollment.
  static const Duration _idleTimeout = Duration(minutes: 10);

  final Rx<AdminPhase> phase = AdminPhase.locked.obs;
  final RxString error = ''.obs;
  final RxString resultMessage = ''.obs;
  final RxBool resultOk = false.obs;
  final RxList<Map<String, dynamic>> roster = <Map<String, dynamic>>[].obs;
  final RxString authorisedBy = ''.obs;
  final RxBool busy = false.obs;

  CameraController? camera;
  final RxBool cameraReady = false.obs;

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  String? _session;
  Map<String, dynamic>? _selected;
  Timer? _idleTimer;

  Map<String, dynamic>? get selected => _selected;

  @override
  void onClose() {
    _idleTimer?.cancel();
    camera?.dispose();
    _detector.close();
    _crud.dispose();
    super.onClose();
  }

  void _touch() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, close);
  }

  Future<void> unlock(String code) async {
    busy.value = true;
    error.value = '';

    final result = await _crud.post(KioskApi.openAdmin, {'code': code.trim()});
    busy.value = false;

    if (result.isBlocking) {
      _kiosk.applyBlocking(result);
      return;
    }

    if (!result.isSuccess) {
      // Unknown, expired, and already-used all answer the same way — the
      // server refuses to be an oracle, and neither should this screen.
      error.value = 'الكود غير صالح أو تم استخدامه. اطلب كودًا جديدًا.';
      return;
    }

    _session = result.data['admin_session'] as String?;
    authorisedBy.value = (result.data['authorised_by']?['name'] ?? '') as String;

    _touch();
    await _initCamera();
    await loadRoster();
  }

  Future<void> _initCamera() async {
    if (cameraReady.value) return;
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller =
          CameraController(front, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      camera = controller;
      cameraReady.value = true;
    } catch (e) {
      debugPrint('admin camera init failed: $e');
      cameraReady.value = false;
    }
  }

  Future<void> loadRoster() async {
    busy.value = true;
    final result = await _crud.post(KioskApi.adminRoster, {}, adminSession: _session);
    busy.value = false;

    if (result.isBlocking) {
      _kiosk.applyBlocking(result);
      return;
    }
    if (!result.isSuccess) {
      // Expired session: back to the code prompt rather than a dead list.
      phase.value = AdminPhase.locked;
      error.value = 'انتهت جلسة الإدارة. أدخل كود دخول جديدًا.';
      return;
    }

    roster.value = List<Map<String, dynamic>>.from(
      (result.data['employees'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );
    phase.value = AdminPhase.roster;
    _touch();
  }

  void select(Map<String, dynamic> employee) {
    _selected = employee;
    error.value = '';
    phase.value = AdminPhase.capturing;
    _touch();
  }

  /// Captures and enrols the selected employee.
  ///
  /// [confirmReplace] must be set explicitly when the employee is already
  /// enrolled, so replacing somebody's face is a deliberate act rather than a
  /// silent overwrite nobody can spot afterwards.
  Future<void> captureAndEnroll({bool confirmReplace = false}) async {
    final employee = _selected;
    final controller = camera;
    if (employee == null) return;

    if (controller == null || !cameraReady.value) {
      _finish(false, 'الكاميرا غير متاحة على هذا الجهاز.');
      return;
    }

    phase.value = AdminPhase.saving;
    _touch();

    try {
      final shot = await controller.takePicture();
      final bytes = await shot.readAsBytes();
      final faces =
          await _detector.processImage(InputImage.fromFilePath(shot.path));

      if (faces.isEmpty) {
        _finish(false, 'لم نتمكن من رؤية وجه. اضبط الإضاءة وحاول مرة أخرى.');
        return;
      }
      if (faces.length > 1) {
        // Two faces in frame is how the wrong person ends up enrolled onto
        // somebody else's record.
        _finish(false, 'يوجد أكثر من شخص أمام الكاميرا. اترك الموظف وحده.');
        return;
      }

      final face = faces.first;

      // A local quality gate to save a round trip and give an immediate,
      // actionable message. The SERVER still decides — a patched tablet
      // reporting perfect quality would poison the roster it later matches
      // against.
      final quality = FaceQuality.evaluate(face, 1080);
      if (!quality.isAcceptable) {
        _finish(false, _qualityMessage(quality.messageKey));
        return;
      }

      final embedding = await FaceEmbedder.instance.embed(bytes, face);
      if (embedding == null) {
        _finish(false, 'تعذّرت معالجة الصورة. حاول مرة أخرى.');
        return;
      }

      final result = await _crud.post(
        KioskApi.adminEnroll,
        {
          'employee_id': employee['id'],
          'embedding': embedding,
          'model_version': FaceEmbedder.modelVersion,
          'quality_score': quality.score,
          'image': 'data:image/jpeg;base64,${base64Encode(bytes)}',
          'confirm_replace': confirmReplace,
        },
        adminSession: _session,
        isUpload: true,
      );

      if (result.isBlocking) {
        _kiosk.applyBlocking(result);
        return;
      }

      if (result.httpStatus == 409) {
        // Already enrolled. Ask before replacing.
        _finish(false, 'هذا الموظف مسجّل بالفعل. أكّد الاستبدال لتسجيل وجه جديد.',
            needsConfirm: true);
        return;
      }

      if (!result.isSuccess) {
        _finish(false, 'تعذّر التسجيل: الصورة لم تجتز فحص الجودة على الخادم.');
        return;
      }

      _finish(true, 'تم تسجيل ${employee['name']}');
      await loadRoster();
    } catch (e) {
      debugPrint('enroll failed: $e');
      _finish(false, 'حدث خطأ أثناء التسجيل. حاول مرة أخرى.');
    }
  }

  String _qualityMessage(String? key) => switch (key) {
        'face_quality_too_far' => 'الموظف بعيد عن الكاميرا. اطلب منه الاقتراب.',
        'face_quality_too_close' => 'الموظف قريب جدًا. اطلب منه التراجع قليلًا.',
        'face_quality_look_straight' => 'اطلب من الموظف النظر إلى الكاميرا مباشرة.',
        _ => 'جودة الصورة منخفضة. حسّن الإضاءة وحاول مرة أخرى.',
      };

  final RxBool needsReplaceConfirm = false.obs;

  void _finish(bool ok, String message, {bool needsConfirm = false}) {
    resultOk.value = ok;
    resultMessage.value = message;
    needsReplaceConfirm.value = needsConfirm;
    phase.value = AdminPhase.result;
    _touch();
  }

  void backToRoster() {
    _selected = null;
    needsReplaceConfirm.value = false;
    phase.value = AdminPhase.roster;
    _touch();
  }

  /// Ends the session. [releaseKioskMode] unpins the tablet — the only route to
  /// that, which is why it costs an access code.
  Future<void> close({bool releaseKioskMode = false}) async {
    _idleTimer?.cancel();

    if (_session != null) {
      await _crud.post(
        KioskApi.adminClose,
        {'release_kiosk_mode': releaseKioskMode},
        adminSession: _session,
      );
    }

    if (releaseKioskMode) {
      // The only route out of screen pinning, and it cost an
      // administrator-generated code to get here.
      await KioskLock.exit();
    }

    _session = null;
    _selected = null;
    roster.clear();
    error.value = '';
    phase.value = AdminPhase.locked;
  }
}
