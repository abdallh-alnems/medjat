import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:medjat_shared/medjat_shared.dart';

import '../core/api/kiosk_api.dart';
import '../core/network/kiosk_crud.dart';
import '../core/network/kiosk_result.dart';
import 'kiosk_controller.dart';

/// Where the interaction currently is.
enum IdentifyPhase {
  /// Waiting for someone to start. A kiosk does not watch the room.
  idle,

  /// Camera up, liveness challenge on screen.
  capturing,

  /// Embedding sent; the server is deciding.
  thinking,

  /// Someone was resolved. Waiting for them to confirm the punch.
  confirming,

  /// Recorded.
  done,

  /// Not identified, or refused. Carries a sentence, not a code.
  failed,

  /// Typing a personal code instead. A phase rather than a route: a kiosk has
  /// no back stack, and the identification screen must not stay alive
  /// underneath where a revocation could not reach it.
  codeEntry,
}

/// Drives one identification: challenge, capture, embed, identify, punch.
///
/// The tablet sends an **embedding and a liveness flag** and nothing else that
/// resembles a decision. The server scores, applies threshold and margin, and
/// issues a ticket naming the resolved employee — so this controller cannot
/// identify as one person and punch as another even if it wanted to.
class IdentifyController extends GetxController {
  IdentifyController({KioskCrud? crud}) : _crud = crud ?? KioskCrud();

  final KioskCrud _crud;
  final KioskController _kiosk = Get.find<KioskController>();

  final Rx<IdentifyPhase> phase = IdentifyPhase.idle.obs;
  final RxString messageAr = ''.obs;
  final RxString employeeName = ''.obs;
  final RxString nextAction = ''.obs;
  final RxBool codeFallbackOffered = false.obs;
  final RxString livenessPrompt = ''.obs;

  CameraController? camera;
  final RxBool cameraReady = false.obs;

  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true, // eye-open / smiling probabilities
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  String? _nonce;
  String? _ticket;
  int? _recognitionLogId;
  LivenessDetector? _liveness;
  Timer? _resetTimer;

  @override
  void onInit() {
    super.onInit();
    _initCamera();
  }

  @override
  void onClose() {
    _resetTimer?.cancel();
    camera?.dispose();
    _detector.close();
    _crud.dispose();
    super.onClose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      camera = controller;
      cameraReady.value = true;
    } catch (e) {
      // A kiosk with no working camera is not broken — it falls back to the
      // personal code rather than presenting a dead screen (FR edge case).
      debugPrint('camera init failed: $e');
      cameraReady.value = false;
    }
  }

  /// Begins an identification. Called when somebody taps the screen.
  Future<void> start() async {
    if (phase.value == IdentifyPhase.thinking) return;

    _reset();
    phase.value = IdentifyPhase.capturing;

    final challenge = await _crud.post(KioskApi.challenge, {'purpose': 'punch'});
    if (challenge.isBlocking) {
      _kiosk.applyBlocking(challenge);
      return;
    }
    if (!challenge.isSuccess) {
      _fail('تعذّر بدء التسجيل. حاول مرة أخرى.');
      return;
    }

    _nonce = challenge.data['nonce'] as String?;
    final name = challenge.data['challenge'] as String?;
    _liveness = LivenessDetector(
      LivenessChallenge.fromApi(name) ?? LivenessChallenge.blink,
    );
    livenessPrompt.value = _promptFor(name);

    await _captureAndIdentify();
  }

  String _promptFor(String? challenge) => switch (challenge) {
        'blink' => 'انظر إلى الكاميرا وارمش',
        'turn_left' => 'أدر رأسك يسارًا',
        'turn_right' => 'أدر رأسك يمينًا',
        'smile' => 'ابتسم',
        _ => 'انظر إلى الكاميرا',
      };

  Future<void> _captureAndIdentify() async {
    final controller = camera;
    if (controller == null || !cameraReady.value) {
      _fail('الكاميرا غير متاحة. استخدم رمزك الشخصي.', offerCode: true);
      return;
    }

    try {
      // Sample a few frames so the liveness challenge has motion to observe.
      // A single still frame proves nothing a printed photograph could not.
      XFile? best;
      Face? bestFace;

      for (var i = 0; i < 12; i++) {
        final shot = await controller.takePicture();
        final faces = await _detector.processImage(InputImage.fromFilePath(shot.path));

        if (faces.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          continue;
        }

        final face = faces.first;
        _liveness?.update(face);
        best = shot;
        bestFace = face;

        if (_liveness?.passed ?? false) break;
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }

      if (best == null || bestFace == null) {
        _fail('لم نتمكن من رؤية وجهك. اقترب من الكاميرا وحاول مرة أخرى.',
            offerCode: true);
        return;
      }

      phase.value = IdentifyPhase.thinking;

      final bytes = await best.readAsBytes();
      final embedding = await FaceEmbedder.instance.embed(bytes, bestFace);

      if (embedding == null) {
        _fail('الصورة غير واضحة. حاول مرة أخرى.', offerCode: true);
        return;
      }

      final result = await _crud.post(
        KioskApi.identify,
        {
          'nonce': _nonce,
          'embedding': embedding,
          'model_version': FaceEmbedder.modelVersion,
          // Reported, never trusted: the server re-evaluates against the
          // challenge it issued and decides for itself.
          'liveness_passed': _liveness?.passed ?? false,
          'image': 'data:image/jpeg;base64,${base64Encode(bytes)}',
        },
        isUpload: true,
      );

      _handleIdentifyResult(result);
    } catch (e) {
      debugPrint('capture failed: $e');
      _fail('حدث خطأ أثناء التصوير. حاول مرة أخرى.', offerCode: true);
    }
  }

  void _handleIdentifyResult(KioskResult result) {
    if (result.isBlocking) {
      _kiosk.applyBlocking(result);
      return;
    }

    if (!result.isSuccess) {
      _fail('تعذّر التحقق. حاول مرة أخرى.', offerCode: true);
      return;
    }

    final data = result.data;
    final outcome = data['outcome'] as String?;

    if (outcome != 'matched') {
      // A failed identification is a normal outcome, not an error: somebody
      // stood in front of a camera and was not recognised.
      _fail(
        _outcomeMessage(outcome, data['message_key'] as String?),
        offerCode: data['code_fallback_available'] == true,
      );
      return;
    }

    employeeName.value = (data['employee']?['name'] ?? '') as String;
    nextAction.value = (data['next_action'] ?? 'check_in') as String;
    _ticket = data['punch_ticket'] as String?;
    _recognitionLogId = data['recognition_log_id'] as int?;
    phase.value = IdentifyPhase.confirming;

    // The confirmation screen is not left open indefinitely: the next person in
    // the queue must not be able to punch as whoever is still on screen.
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 20), _reset);
  }

  String _outcomeMessage(String? outcome, String? key) => switch (outcome) {
        'ambiguous' =>
          'الصورة غير واضحة بما يكفي للتأكد من هويتك. اقترب قليلًا وحاول ثانية.',
        'no_match' => 'لم نتعرّف عليك. جرّب مرة أخرى أو استخدم رمزك الشخصي.',
        'not_enrolled' => 'وجهك غير مسجّل بعد. اطلب من المشرف تسجيله.',
        'out_of_branch' => 'أنت غير مسجّل على هذا الفرع.',
        'wrong_method' => 'طريقة تسجيل حضورك ليست الكيوسك. استخدم تطبيق مِدجات.',
        'liveness_failed' => 'انظر إلى الكاميرا مباشرة ونفّذ الحركة المطلوبة.',
        'too_soon' => 'سجّلنا لك بالفعل منذ قليل.',
        'out_of_range' => 'هذا الجهاز خارج نطاق الفرع. أبلغ المسؤول.',
        _ => 'لم نتعرّف عليك. حاول مرة أخرى.',
      };

  /// A punch that was sent but whose outcome is unknown.
  ///
  /// Held **in memory only**, deliberately. Writing it to disk would make this
  /// an offline queue, and the whole design turns on there not being one: a
  /// punch that survives a restart is a punch the tablet is promising to make
  /// on somebody's behalf, hours later, with no server having agreed to it.
  /// Losing it on restart is the honest behaviour — the employee is standing
  /// right there and can try again.
  Map<String, dynamic>? _pendingPunch;

  bool get hasPendingPunch => _pendingPunch != null;

  /// Records the punch the employee just confirmed.
  Future<void> confirm() async {
    if (_ticket == null) return;

    phase.value = IdentifyPhase.thinking;

    // One key per punch, generated once. A retry MUST reuse it — that is the
    // entire replay guarantee: the server recognises the key, returns the
    // original result, and the employee is not punched twice.
    _pendingPunch = {
      'punch_ticket': _ticket,
      'recognition_log_id': _recognitionLogId ?? 0,
      'direction': nextAction.value,
      'idempotency_key': _uuid(),
    };

    await _sendPendingPunch();
  }

  Future<void> _sendPendingPunch() async {
    final payload = _pendingPunch;
    if (payload == null) return;

    final result = await _crud.post(KioskApi.punch, payload);

    if (result.status == KioskStatus.offline || result.status == KioskStatus.failure) {
      // The request may or may not have reached the server. Keep the payload —
      // with its original key — and retry when the connection returns, rather
      // than telling the employee it failed when it may well have succeeded.
      _fail('انقطع الاتصال أثناء التسجيل. سنعيد المحاولة تلقائيًا.');
      return;
    }

    // Any definitive answer ends the attempt: it either recorded, or it was
    // refused for a reason retrying will not change.
    _pendingPunch = null;

    if (result.isBlocking) {
      _kiosk.applyBlocking(result);
      return;
    }

    if (!result.isSuccess) {
      _fail('تعذّر تسجيل الحضور. حاول مرة أخرى.');
      return;
    }

    phase.value = IdentifyPhase.done;
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 4), _reset);
  }

  /// Called by the shell when the tablet comes back online.
  ///
  /// Replays the outstanding punch with its original key. If the first attempt
  /// did land, the server answers `replayed: true` with the same attendance row
  /// and nothing is duplicated.
  Future<void> retryPendingPunch() async {
    if (_pendingPunch == null) return;
    phase.value = IdentifyPhase.thinking;
    await _sendPendingPunch();
  }

  void _fail(String message, {bool offerCode = false}) {
    messageAr.value = message;
    codeFallbackOffered.value = offerCode && _kiosk.codeFallbackEnabled;
    phase.value = IdentifyPhase.failed;

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 8), _reset);
  }

  void _reset() {
    // A pending punch outlives the screen reset: the interaction is over for
    // the employee, but the tablet still owes the server an answer.
    _resetTimer?.cancel();
    _nonce = null;
    _ticket = null;
    _recognitionLogId = null;
    _liveness = null;
    employeeName.value = '';
    nextAction.value = '';
    messageAr.value = '';
    codeFallbackOffered.value = false;
    livenessPrompt.value = '';
    phase.value = IdentifyPhase.idle;
  }

  void cancel() => _reset();

  void openCodeEntry() {
    _resetTimer?.cancel();
    messageAr.value = '';
    phase.value = IdentifyPhase.codeEntry;
  }

  /// Identifies by personal code. Returns the same envelope as the face path,
  /// so the confirmation step below is identical either way.
  Future<void> submitCode(String code) async {
    phase.value = IdentifyPhase.thinking;

    final result = await _crud.post(KioskApi.identifyByCode, {'code': code.trim()});

    if (result.isBlocking) {
      _kiosk.applyBlocking(result);
      return;
    }

    if (result.status == KioskStatus.throttled) {
      _fail('محاولات خاطئة كثيرة. انتظر قليلًا ثم حاول مرة أخرى.');
      return;
    }

    if (!result.isSuccess) {
      _fail('الرمز الشخصي غير مفعّل في هذا الفرع.');
      return;
    }

    final data = result.data;
    if (data['outcome'] != 'matched') {
      messageAr.value = _outcomeMessage(
        data['outcome'] as String?,
        data['message_key'] as String?,
      );
      if (data['outcome'] == 'no_match') {
        messageAr.value = 'الرمز غير صحيح.';
      }
      // Stay on the keypad: a mistyped digit should not cost a trip back
      // through the whole flow.
      phase.value = IdentifyPhase.codeEntry;
      return;
    }

    employeeName.value = (data['employee']?['name'] ?? '') as String;
    nextAction.value = (data['next_action'] ?? 'check_in') as String;
    _ticket = data['punch_ticket'] as String?;
    _recognitionLogId = data['recognition_log_id'] as int?;
    phase.value = IdentifyPhase.confirming;

    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 20), _reset);
  }

  /// RFC 4122 v4 from a cryptographic source.
  ///
  /// The whole replay guarantee rests on this being unique: two punches sharing
  /// a key would make the second one silently return the first one's result,
  /// so the second employee would be told they clocked in when the record
  /// belongs to somebody else. Clock-derived keys are not good enough — two
  /// tablets in the same branch can read the same microsecond.
  static String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
