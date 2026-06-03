import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constant/theme/app_text_styles.dart';
import '../../../../core/services/face/face_service.dart';
import '../../../../logic/controller/station/station_controller.dart';

class KioskFaceCheckInScreen extends StatefulWidget {
  const KioskFaceCheckInScreen({super.key});

  @override
  State<KioskFaceCheckInScreen> createState() => _KioskFaceCheckInScreenState();
}

class _KioskFaceCheckInScreenState extends State<KioskFaceCheckInScreen> {
  final _controller = Get.find<StationController>();
  final _faceService = FaceService();

  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  bool _isProcessing = false;

  LivenessChallenge? _currentChallenge;
  String _statusMessage = '';
  bool _challengeComplete = false;

  final List<double> _eyeOpenProbabilities = [];
  final List<double> _eulerYValues = [];
  final List<double> _smileProbabilities = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        setState(() => _statusMessage = 'no_camera'.tr);
        return;
      }

      final frontCamera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_onCameraImage);

      setState(() {
        _isCameraReady = true;
        _statusMessage = 'face_position'.tr;
      });
    } catch (e) {
      setState(() => _statusMessage = 'camera_error'.tr);
    }
  }

  void _onCameraImage(CameraImage image) async {
    if (_isProcessing || _challengeComplete) return;
    if (_cameraController == null || _cameras == null) return;

    _isProcessing = true;

    try {
      final inputImage = _faceService.inputImageFromCameraImage(
        image,
        _cameras!.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        ),
      );

      final result = await _faceService.detectFace(inputImage);

      if (!result.detected) {
        if (mounted) {
          setState(() => _statusMessage = 'no_face_detected'.tr);
        }
        _isProcessing = false;
        return;
      }

      final face = result.face!;

      if (_currentChallenge == null) {
        setState(() {
          _currentChallenge = _faceService.randomChallenge();
          _statusMessage = _faceService.challengeLabel(_currentChallenge!).tr;
        });
        _isProcessing = false;
        return;
      }

      switch (_currentChallenge!) {
        case LivenessChallenge.blink:
          final leftEye = face.leftEyeOpenProbability ?? 1.0;
          final rightEye = face.rightEyeOpenProbability ?? 1.0;
          final avgEye = (leftEye + rightEye) / 2;
          _eyeOpenProbabilities.add(avgEye);
          if (_eyeOpenProbabilities.length > 30) {
            _eyeOpenProbabilities.removeAt(0);
          }
          if (_faceService.checkBlink(_eyeOpenProbabilities)) {
            _challengeComplete = true;
          }
          break;

        case LivenessChallenge.turnLeft:
        case LivenessChallenge.turnRight:
          final eulerY = face.headEulerAngleY ?? 0;
          _eulerYValues.add(eulerY);
          if (_eulerYValues.length > 30) {
            _eulerYValues.removeAt(0);
          }
          if (_faceService.checkHeadTurn(
            _eulerYValues,
            toLeft: _currentChallenge == LivenessChallenge.turnLeft,
          )) {
            _challengeComplete = true;
          }
          break;

        case LivenessChallenge.smile:
          final smileProb = face.smilingProbability ?? 0;
          _smileProbabilities.add(smileProb);
          if (_smileProbabilities.length > 20) {
            _smileProbabilities.removeAt(0);
          }
          if (_faceService.checkSmile(_smileProbabilities)) {
            _challengeComplete = true;
          }
          break;
      }

      if (_challengeComplete) {
        await _cameraController!.stopImageStream();
        setState(() => _statusMessage = 'matching_face'.tr);

        final embedding = await _faceService.generateEmbedding(image, face);

        final matchResult = await _controller.matchFace(embedding);

        if (matchResult != null && matchResult['matched'] == true) {
          final employeeId = matchResult['employee_id'] as int;
          final confidence = (matchResult['confidence'] as num).toDouble();

          await _controller.checkInOutFace(
            employeeId: employeeId,
            confidence: confidence,
          );
        } else {
          if (mounted) {
            setState(() => _statusMessage = 'face_not_recognized'.tr);
            await Future<void>.delayed(const Duration(seconds: 2));
            _resetForRetry();
          }
        }
      }
    } catch (e) {
      // silently ignore frame processing errors
    }

    _isProcessing = false;
  }

  void _resetForRetry() {
    _currentChallenge = null;
    _challengeComplete = false;
    _eyeOpenProbabilities.clear();
    _eulerYValues.clear();
    _smileProbabilities.clear();
    _isProcessing = false;
    _statusMessage = 'face_position'.tr;

    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      return;
    }
    _cameraController?.startImageStream(_onCameraImage);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCameraPreview(),
                  _buildOverlay(),
                  _buildStatusOverlay(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black54,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back<void>(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            'face_checkin'.tr,
            style: AppTextStyles.h3(context).copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraReady || _cameraController == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return CameraPreview(_cameraController!);
  }

  Widget _buildOverlay() {
    return Center(
      child: Container(
        width: 250,
        height: 300,
        decoration: BoxDecoration(
          border: Border.all(
            color: _challengeComplete ? Colors.green : Colors.white,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildStatusOverlay(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentChallenge != null)
              Icon(
                _challengeIcon(_currentChallenge!),
                color: Colors.white,
                size: 40,
              ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _challengeIcon(LivenessChallenge challenge) {
    switch (challenge) {
      case LivenessChallenge.blink:
        return Icons.visibility_off;
      case LivenessChallenge.turnLeft:
        return Icons.arrow_back;
      case LivenessChallenge.turnRight:
        return Icons.arrow_forward;
      case LivenessChallenge.smile:
        return Icons.emoji_emotions;
    }
  }
}
