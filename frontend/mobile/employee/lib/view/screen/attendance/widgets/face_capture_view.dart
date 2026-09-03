import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/constant/theme/app_colors.dart';
import '../../../../core/constant/theme/app_spacing.dart';
import 'package:permedjat_shared/permedjat_shared.dart';

/// What a completed capture produces.
class FaceCaptureResult {
  final List<double> embedding;
  final double qualityScore;
  final bool livenessPassed;
  final String imageBase64;

  const FaceCaptureResult({
    required this.embedding,
    required this.qualityScore,
    required this.livenessPassed,
    required this.imageBase64,
  });
}

/// Front-camera capture that runs the liveness challenge, checks frame quality,
/// and extracts the face embedding.
///
/// Shared by enrollment and check-in so both go through exactly the same
/// quality bar — an enrollment captured under looser rules would produce an
/// embedding that never matches at check-in.
class FaceCaptureView extends StatefulWidget {
  final LivenessChallenge challenge;
  final bool livenessRequired;
  final ValueChanged<FaceCaptureResult> onCaptured;
  final VoidCallback? onUnavailable;

  const FaceCaptureView({
    super.key,
    required this.challenge,
    required this.livenessRequired,
    required this.onCaptured,
    this.onUnavailable,
  });

  @override
  State<FaceCaptureView> createState() => _FaceCaptureViewState();
}

class _FaceCaptureViewState extends State<FaceCaptureView> {
  CameraController? _camera;
  FaceDetector? _detector;
  late final LivenessDetector _liveness = LivenessDetector(widget.challenge);

  bool _initialising = true;
  bool _capturing = false;
  bool _busyFrame = false;
  String? _error;
  String? _hintKey;
  bool _livenessDone = false;

  /// Throttle: ML Kit on a mid-range phone can't keep up with every frame, and
  /// queuing them makes the preview lag badly.
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  static const _frameInterval = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      await FaceEmbedder.instance.load();

      final cameras = await availableCameras();
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();

      _detector = FaceDetector(
        options: FaceDetectorOptions(
          // Classification gives the eye-open / smiling probabilities the
          // liveness challenge relies on; landmarks are not needed.
          enableClassification: true,
          enableTracking: true,
        ),
      );

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _initialising = false;
      });

      unawaited(_pollFrames());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialising = false;
        _error = 'face_unavailable'.tr;
      });
      widget.onUnavailable?.call();
    }
  }

  /// Polls still frames rather than using an image stream: the YUV→RGB
  /// conversion an image stream needs is platform-specific and error-prone,
  /// while takePicture gives ML Kit and the embedder the same JPEG bytes.
  Future<void> _pollFrames() async {
    while (mounted && !_capturing && _camera != null) {
      final now = DateTime.now();
      if (now.difference(_lastFrame) < _frameInterval || _busyFrame) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        continue;
      }
      _lastFrame = now;
      await _processFrame();
    }
  }

  Future<void> _processFrame() async {
    final camera = _camera;
    final detector = _detector;
    if (camera == null || detector == null || _busyFrame) return;
    _busyFrame = true;

    XFile? shot;
    try {
      shot = await camera.takePicture();
      final faces = await detector.processImage(InputImage.fromFilePath(shot.path));

      if (faces.isEmpty) {
        _setHint('face_hint_no_face');
        return;
      }
      if (faces.length > 1) {
        _setHint('face_hint_multiple_faces');
        return;
      }

      final face = faces.first;
      final bytes = await File(shot.path).readAsBytes();

      final quality = FaceQuality.evaluate(face, camera.value.previewSize?.height.toInt() ?? 720);
      if (!quality.isAcceptable) {
        _setHint(quality.messageKey!);
        return;
      }

      // Liveness first: only once the action is done do we spend the cost of
      // running the embedding model.
      if (widget.livenessRequired && !_livenessDone) {
        final passed = _liveness.update(face);
        if (!passed) {
          _setHint(widget.challenge.instructionKey);
          return;
        }
        if (mounted) setState(() => _livenessDone = true);
      }

      _capturing = true;
      _setHint('face_hint_hold_still');

      final embedding = await FaceEmbedder.instance.embed(bytes, face);
      if (embedding == null) {
        _capturing = false;
        _setHint('face_capture_failed');
        return;
      }

      if (!mounted) return;
      widget.onCaptured(FaceCaptureResult(
        embedding: embedding,
        qualityScore: quality.score,
        livenessPassed: !widget.livenessRequired || _liveness.passed,
        imageBase64: base64Encode(bytes),
      ));
    } catch (_) {
      // A dropped frame is normal under load; the loop simply tries again.
    } finally {
      _busyFrame = false;
      if (shot != null) {
        unawaited(File(shot.path).delete().catchError((_) => File(shot!.path)));
      }
    }
  }

  void _setHint(String key) {
    if (!mounted || _hintKey == key) return;
    setState(() => _hintKey = key);
  }

  @override
  void dispose() {
    _camera?.dispose();
    _detector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_initialising) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _camera == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Text(
            _error ?? 'face_unavailable'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _camera!.value.previewSize?.height ?? 720,
                      height: _camera!.value.previewSize?.width ?? 1280,
                      child: CameraPreview(_camera!),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Container(
                  width: 292,
                  height: 292,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _livenessDone ? colors.brand : colors.borderHairline,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
          child: Text(
            (_hintKey ?? widget.challenge.instructionKey).tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
