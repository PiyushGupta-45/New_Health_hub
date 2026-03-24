// lib/pages/pose_camera_page.dart

import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart' as mlkit;
import 'package:permission_handler/permission_handler.dart';
import '../models/exercise_type.dart';
import '../services/posture_history_service.dart';

enum _PostureQuality {
  correct,
  incorrect,
  neutral,
}

class _AnalysisFeedback {
  const _AnalysisFeedback({
    required this.label,
    required this.voicePrompt,
    required this.quality,
    required this.frameScore,
  });

  final String label;
  final String voicePrompt;
  final _PostureQuality quality;
  final double frameScore;
}

class PoseCameraPage
    extends
        StatefulWidget {
  final ExerciseType exerciseType;

  const PoseCameraPage({
    super.key,
    this.exerciseType = ExerciseType.generalPosture,
  });

  @override
  State<
    PoseCameraPage
  >
  createState() => _PoseCameraPageState();
}

class _PoseCameraPageState
    extends
        State<
          PoseCameraPage
        >
    with
        WidgetsBindingObserver {
  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  bool _isDetecting = false;
  String _postureLabel = "Detecting...";
  double _neckAngle = 0.0;
  double _shoulderAngle = 0.0;
  double _spineAngle = 0.0;
  Pose? _lastPose;
  Size? _imageSize; // size of camera image
  bool _isFrontCamera = false;
  Timer? _beepTimer;
  Timer? _burstStopTimer;
  bool _wasIncorrect = false;
  bool _sessionSaved = false;
  _PostureQuality _activeTone = _PostureQuality.neutral;
  final FlutterTts _tts = FlutterTts();
  DateTime _lastVoiceAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastSpokenMessage = '';
  String _cameraGuidance = 'Align your body in the center of the frame';
  String _voicePrompt = 'Stand tall and stay centered in frame.';
  _PostureQuality _currentQuality = _PostureQuality.neutral;
  int _cameraGuidanceFrames = 0;
  double _currentFrameScore = 0;
  int _correctFrames = 0;
  int _incorrectFrames = 0;
  int _neutralFrames = 0;
  double _frameScoreTotal = 0;
  final PostureHistoryService _postureHistoryService = PostureHistoryService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(
      this,
    );
    _configureVoiceAssistant();
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    );
    _stopBeeping();
    _tts.stop();
    unawaited(_persistSessionIfNeeded());
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    final controller = _cameraController;
    if (controller ==
            null ||
        !controller.value.isInitialized) {
      return;
    }

    if (state ==
        AppLifecycleState.inactive) {
      _stopBeeping();
      controller.stopImageStream();
    } else if (state ==
        AppLifecycleState.resumed) {
      try {
        controller.startImageStream(
          _processCameraImage,
        );
      } catch (
        e
      ) {
        debugPrint(
          'Error restarting image stream: $e',
        );
      }
    }
  }

  Future<
    void
  >
  _initialize() async {
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (mounted) {
          setState(
            () {
              _postureLabel = "Camera permission denied";
            },
          );
        }
        debugPrint(
          'Camera permission denied',
        );
        return;
      }

      // initialize camera
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(
            () {
              _postureLabel = "No cameras found";
            },
          );
        }
        debugPrint(
          'No cameras found',
        );
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (
          camera,
        ) =>
            camera.lensDirection ==
            CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _isFrontCamera =
          selectedCamera.lensDirection ==
          CameraLensDirection.front;

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.nv21,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // create ML Kit pose detector
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: PoseDetectionModel.accurate,
        ),
      );

      // start image stream
      await _cameraController!.startImageStream(
        _processCameraImage,
      );

      if (mounted) {
        setState(
          () {},
        );
      }
    } catch (
      e
    ) {
      debugPrint(
        'Error initializing camera: $e',
      );
      if (mounted) {
        setState(
          () {
            _postureLabel = "Error: ${e.toString()}";
          },
        );
      }
    }
  }

  // Map CameraImage rotation degrees to InputImageRotation
  InputImageRotation _rotationIntToImageRotation(
    int rotation,
  ) {
    switch (rotation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
      default:
        return InputImageRotation.rotation270deg;
    }
  }

  Future<
    void
  >
  _processCameraImage(
    CameraImage image,
  ) async {
    if (_isDetecting ||
        _poseDetector ==
            null) {
      return;
    }
    _isDetecting = true;

    try {
      // Convert CameraImage to bytes and metadata for ML Kit InputImage
      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(
          plane.bytes,
        );
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final int rotation = _cameraController!.description.sensorOrientation;
      final inputImageRotation = _rotationIntToImageRotation(
        rotation,
      );

      // Store image size in the same orientation as the preview widget
      if (rotation ==
              90 ||
          rotation ==
              270) {
        _imageSize = Size(
          image.height.toDouble(),
          image.width.toDouble(),
        );
      } else {
        _imageSize = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
      }

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      // Determine image format - NV21 is the default for Android camera
      InputImageFormat inputImageFormat = InputImageFormat.nv21;
      if (image.format.group ==
          ImageFormatGroup.yuv420) {
        inputImageFormat = InputImageFormat.yuv420;
      } else if (image.format.group ==
          ImageFormatGroup.bgra8888) {
        inputImageFormat = InputImageFormat.bgra8888;
      }

      // Get bytesPerRow from first plane (for NV21 format)
      final bytesPerRow = image.planes.isNotEmpty
          ? image.planes.first.bytesPerRow
          : 0;

      // Create input image metadata
      final inputImageMetadata = mlkit.InputImageMetadata(
        size: imageSize,
        rotation: inputImageRotation,
        format: inputImageFormat,
        bytesPerRow: bytesPerRow,
      );

      // Create InputImage from bytes
      final inputImage = mlkit.InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageMetadata,
      );

      // Run pose detection
      final poses = await _poseDetector!.processImage(
        inputImage,
      );

      if (poses.isNotEmpty) {
        _lastPose = poses.first;
        _analyzePose(
          _lastPose!,
        );
      } else {
        // No pose detected - update UI to show detection status
        _currentQuality = _PostureQuality.neutral;
        _voicePrompt = 'Step into view so I can start analyzing your posture.';
        _setPostureTone(
          _PostureQuality.neutral,
        );
        if (mounted &&
            _lastPose ==
                null) {
          setState(
            () {
              _postureLabel = "Position yourself in frame";
              _cameraGuidance = "Center your full body in frame";
            },
          );
        }
      }
    } catch (
      e
    ) {
      debugPrint(
        'Error processing camera image: $e',
      );
      // Don't update UI on every frame error to avoid flickering
    } finally {
      _isDetecting = false;
    }
  }

  // ---------- Angle calculations and posture rules ----------
  double _calculateAngle(
    Offset a,
    Offset b,
    Offset c,
  ) {
    final ba = Offset(
      a.dx -
          b.dx,
      a.dy -
          b.dy,
    );
    final bc = Offset(
      c.dx -
          b.dx,
      c.dy -
          b.dy,
    );

    final dot =
        ba.dx *
            bc.dx +
        ba.dy *
            bc.dy;
    final magBA = sqrt(
      ba.dx *
              ba.dx +
          ba.dy *
              ba.dy,
    );
    final magBC = sqrt(
      bc.dx *
              bc.dx +
          bc.dy *
              bc.dy,
    );

    if (magBA *
            magBC ==
        0) {
      return 0.0;
    }
    double cosAngle =
        dot /
        (magBA *
            magBC);

    // numeric safety
    cosAngle = cosAngle.clamp(
      -1.0,
      1.0,
    );

    double angleRad = acos(
      cosAngle,
    );
    return angleRad *
        180 /
        pi;
  }

  void _analyzePose(
    Pose pose,
  ) {
    _updateCameraGuidance(
      pose,
    );

    // Route to exercise-specific analysis
    switch (widget.exerciseType) {
      case ExerciseType.generalPosture:
        _analyzeGeneralPosture(
          pose,
        );
        break;
      case ExerciseType.squat:
        _analyzeSquat(
          pose,
        );
        break;
      case ExerciseType.pushUp:
        _analyzePushUp(
          pose,
        );
        break;
      case ExerciseType.plank:
        _analyzePlank(
          pose,
        );
        break;
      case ExerciseType.lunge:
        _analyzeLunge(
          pose,
        );
        break;
      case ExerciseType.deadlift:
        _analyzeDeadlift(
          pose,
        );
        break;
      case ExerciseType.overheadPress:
        _analyzeOverheadPress(
          pose,
        );
        break;
      case ExerciseType.pullUp:
        _analyzePullUp(
          pose,
        );
        break;
      case ExerciseType.bridge:
        _analyzeBridge(
          pose,
        );
        break;
      case ExerciseType.mountainClimber:
        _analyzeMountainClimber(
          pose,
        );
        break;
    }

    final quality = _currentQuality;
    _setPostureTone(quality);
    switch (quality) {
      case _PostureQuality.correct:
        _correctFrames++;
        break;
      case _PostureQuality.incorrect:
        _incorrectFrames++;
        break;
      case _PostureQuality.neutral:
        _neutralFrames++;
        break;
    }
    _frameScoreTotal += _currentFrameScore.clamp(0, 100);
    unawaited(
      _speakFeedbackIfNeeded(),
    );
  }

  Future<void> _persistSessionIfNeeded() async {
    if (_sessionSaved) return;
    final totalFrames = _correctFrames + _incorrectFrames + _neutralFrames;
    if (totalFrames < 10) return;

    _sessionSaved = true;
    final score = (_frameScoreTotal / totalFrames).clamp(0, 100).toDouble();
    final feedback = _sanitizeFeedback(_postureLabel);

    await _postureHistoryService.saveSession(
      PostureSessionRecord(
        id: '${widget.exerciseType.name}_${DateTime.now().millisecondsSinceEpoch}',
        exerciseType: widget.exerciseType,
        score: score,
        correctFrames: _correctFrames,
        incorrectFrames: _incorrectFrames,
        neutralFrames: _neutralFrames,
        feedback: feedback,
        recordedAt: DateTime.now(),
      ),
    );
  }

  String _sanitizeFeedback(String label) {
    return label
        .replaceAll(RegExp(r'[^ -~]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll('Good ', 'Good ');
  }

  void _setPostureTone(
    _PostureQuality quality,
  ) {
    switch (quality) {
      case _PostureQuality.incorrect:
        _wasIncorrect = true;
        if (_activeTone !=
            _PostureQuality.incorrect) {
          _activeTone = _PostureQuality.incorrect;
          _startBeeping(
            interval: const Duration(
              milliseconds: 800,
            ),
          );
        }
        break;
      case _PostureQuality.correct:
        if (_wasIncorrect) {
          _wasIncorrect = false;
          _activeTone = _PostureQuality.correct;
          _startBeeping(
            interval: const Duration(
              milliseconds: 220,
            ),
            autoStopAfter: const Duration(
              seconds: 3,
            ),
          );
        }
        break;
      case _PostureQuality.neutral:
        _activeTone = _PostureQuality.neutral;
        _stopBeeping();
        break;
    }
  }

  void _startBeeping({
    required Duration interval,
    Duration? autoStopAfter,
  }) {
    _stopBeeping();
    _playBeep();
    _beepTimer = Timer.periodic(
      interval,
      (_) => _playBeep(),
    );
    if (autoStopAfter !=
        null) {
      _burstStopTimer = Timer(
        autoStopAfter,
        _stopBeeping,
      );
    }
  }

  void _playBeep() {
    SystemSound.play(
      SystemSoundType.alert,
    );
  }

  void _stopBeeping() {
    _beepTimer?.cancel();
    _beepTimer = null;
    _burstStopTimer?.cancel();
    _burstStopTimer = null;
  }

  Future<void> _configureVoiceAssistant() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.47);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(false);
    } catch (e) {
      debugPrint('Voice assistant config failed: $e');
    }
  }

  void _updateCameraGuidance(
    Pose pose,
  ) {
    if (_imageSize == null) return;

    final points = pose.landmarks.values.toList();
    if (points.isEmpty) return;

    final xs = points.map((p) => p.x);
    final ys = points.map((p) => p.y);
    final minX = xs.reduce(min);
    final maxX = xs.reduce(max);
    final minY = ys.reduce(min);
    final maxY = ys.reduce(max);

    final frameW = _imageSize!.width;
    final frameH = _imageSize!.height;
    final widthRatio = (maxX - minX) / frameW;
    final heightRatio = (maxY - minY) / frameH;
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    String message = 'Camera framing looks good';

    if (widthRatio < 0.18 || heightRatio < 0.28) {
      message = 'Step a little closer so your joints are easier to track';
    } else if (widthRatio > 0.92 || heightRatio > 0.95) {
      message = 'Move slightly back so your full body stays visible';
    } else if (centerX < frameW * 0.35) {
      message = 'Shift a little to your right to center your body';
    } else if (centerX > frameW * 0.65) {
      message = 'Shift a little to your left to center your body';
    } else if (centerY < frameH * 0.30) {
      message = 'Lower the camera a touch so your full body fits in frame';
    } else if (centerY > frameH * 0.75) {
      message = 'Raise the camera slightly so I can see more of your posture';
    }

    if (message == 'Camera framing looks good') {
      _cameraGuidanceFrames = 0;
    } else {
      _cameraGuidanceFrames++;
    }

    if (message != _cameraGuidance) {
      if (mounted) {
        setState(() {
          _cameraGuidance = message;
        });
      } else {
        _cameraGuidance = message;
      }
    }
  }

  String _buildVoicePrompt() {
    final shouldPrioritizeCamera =
        _currentQuality == _PostureQuality.neutral &&
        _cameraGuidance != 'Camera framing looks good' &&
        _cameraGuidanceFrames >= 18;

    if (shouldPrioritizeCamera) {
      return _cameraGuidance;
    }

    return _voicePrompt;
  }

  Future<void> _speakFeedbackIfNeeded() async {
    final message = _buildVoicePrompt();
    final now = DateTime.now();
    final sinceLast = now.difference(_lastVoiceAt);

    if (message == _lastSpokenMessage && sinceLast < const Duration(seconds: 5)) {
      return;
    }
    if (sinceLast < const Duration(milliseconds: 1500)) {
      return;
    }

    _lastVoiceAt = now;
    _lastSpokenMessage = message;

    try {
      await _tts.stop();
      await _tts.speak(message);
    } catch (e) {
      debugPrint('Voice assistant speech failed: $e');
    }
  }

  // Helper method to get common landmarks
  Map<
    String,
    Offset?
  >
  _getLandmarks(
    Pose pose,
  ) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftEar = pose.landmarks[PoseLandmarkType.leftEar];
    final rightEar = pose.landmarks[PoseLandmarkType.rightEar];

    return {
      'leftShoulder':
          leftShoulder !=
              null
          ? Offset(
              leftShoulder.x,
              leftShoulder.y,
            )
          : null,
      'rightShoulder':
          rightShoulder !=
              null
          ? Offset(
              rightShoulder.x,
              rightShoulder.y,
            )
          : null,
      'leftHip':
          leftHip !=
              null
          ? Offset(
              leftHip.x,
              leftHip.y,
            )
          : null,
      'rightHip':
          rightHip !=
              null
          ? Offset(
              rightHip.x,
              rightHip.y,
            )
          : null,
      'leftKnee':
          leftKnee !=
              null
          ? Offset(
              leftKnee.x,
              leftKnee.y,
            )
          : null,
      'rightKnee':
          rightKnee !=
              null
          ? Offset(
              rightKnee.x,
              rightKnee.y,
            )
          : null,
      'leftAnkle':
          leftAnkle !=
              null
          ? Offset(
              leftAnkle.x,
              leftAnkle.y,
            )
          : null,
      'rightAnkle':
          rightAnkle !=
              null
          ? Offset(
              rightAnkle.x,
              rightAnkle.y,
            )
          : null,
      'leftElbow':
          leftElbow !=
              null
          ? Offset(
              leftElbow.x,
              leftElbow.y,
            )
          : null,
      'rightElbow':
          rightElbow !=
              null
          ? Offset(
              rightElbow.x,
              rightElbow.y,
            )
          : null,
      'leftWrist':
          leftWrist !=
              null
          ? Offset(
              leftWrist.x,
              leftWrist.y,
            )
          : null,
      'rightWrist':
          rightWrist !=
              null
          ? Offset(
              rightWrist.x,
              rightWrist.y,
            )
          : null,
      'nose':
          nose !=
              null
          ? Offset(
              nose.x,
              nose.y,
            )
          : null,
      'leftEar':
          leftEar !=
              null
          ? Offset(
              leftEar.x,
              leftEar.y,
            )
          : null,
      'rightEar':
          rightEar !=
              null
          ? Offset(
              rightEar.x,
              rightEar.y,
            )
          : null,
    };
  }

  Offset? _midpoint(
    Offset? a,
    Offset? b,
  ) {
    if (a != null && b != null) {
      return Offset(
        (a.dx + b.dx) / 2,
        (a.dy + b.dy) / 2,
      );
    }
    return a ?? b;
  }

  double _distance(
    Offset a,
    Offset b,
  ) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return sqrt(dx * dx + dy * dy);
  }

  double _distanceToLine(
    Offset point,
    Offset lineA,
    Offset lineB,
  ) {
    final numerator =
        ((lineB.dy - lineA.dy) * point.dx) -
        ((lineB.dx - lineA.dx) * point.dy) +
        (lineB.dx * lineA.dy) -
        (lineB.dy * lineA.dx);
    final denominator = _distance(lineA, lineB);
    if (denominator == 0) {
      return 0;
    }
    return numerator.abs() / denominator;
  }

  double? _averageValue(
    List<double?> values,
  ) {
    final filtered = values.whereType<double>().toList();
    if (filtered.isEmpty) {
      return null;
    }
    final total = filtered.fold<double>(
      0,
      (sum, value) => sum + value,
    );
    return total / filtered.length;
  }

  double _referenceScale(
    Map<String, Offset?> landmarks,
  ) {
    final shoulderCenter = _midpoint(
      landmarks['leftShoulder'],
      landmarks['rightShoulder'],
    );
    final hipCenter = _midpoint(
      landmarks['leftHip'],
      landmarks['rightHip'],
    );
    final ankleCenter = _midpoint(
      landmarks['leftAnkle'],
      landmarks['rightAnkle'],
    );

    final torso = shoulderCenter != null && hipCenter != null
        ? _distance(shoulderCenter, hipCenter)
        : 0.0;
    final leg = hipCenter != null && ankleCenter != null
        ? _distance(hipCenter, ankleCenter)
        : 0.0;

    return max(max(torso, leg), 40.0);
  }

  void _applyFeedback(
    _AnalysisFeedback feedback,
  ) {
    _currentQuality = feedback.quality;
    _voicePrompt = feedback.voicePrompt;
    _currentFrameScore = feedback.frameScore;
    setState(() {
      _postureLabel = feedback.label;
    });
  }

  _AnalysisFeedback _neutralFeedback({
    required String label,
    required String voicePrompt,
  }) {
    return _AnalysisFeedback(
      label: label,
      voicePrompt: voicePrompt,
      quality: _PostureQuality.neutral,
      frameScore: 50,
    );
  }

  _AnalysisFeedback _buildExerciseFeedback({
    required String successLabel,
    required String successVoice,
    required List<String> corrections,
    List<String> highlights = const <String>[],
  }) {
    if (corrections.length >= 3) {
      final label = corrections.take(2).join(' ');
      final voice = corrections.length > 1
          ? '${corrections[0]} Then ${corrections[1].toLowerCase()}'
          : corrections.first;
      return _AnalysisFeedback(
        label: label,
        voicePrompt: '$voice Stay smooth and controlled.',
        quality: _PostureQuality.incorrect,
        frameScore: 45,
      );
    }

    if (corrections.length == 2) {
      final label = 'Good overall. ${corrections[0]} ${corrections[1]}';
      final voice =
          '${corrections[0]} Then ${corrections[1].toLowerCase()} Overall form is close.';
      return _AnalysisFeedback(
        label: label,
        voicePrompt: voice,
        quality: _PostureQuality.neutral,
        frameScore: 62,
      );
    }

    if (corrections.length == 1) {
      final label = 'Almost there. ${corrections.first}';
      final voice = '${corrections.first} The rest of the movement looks good.';
      return _AnalysisFeedback(
        label: label,
        voicePrompt: voice,
        quality: _PostureQuality.neutral,
        frameScore: 78,
      );
    }

    final label = highlights.isNotEmpty ? highlights.first : successLabel;
    final voice = highlights.isNotEmpty
        ? '${highlights.first} $successVoice'
        : successVoice;
    return _AnalysisFeedback(
      label: label,
      voicePrompt: voice,
      quality: _PostureQuality.correct,
      frameScore: highlights.isNotEmpty ? 94 : 90,
    );
  }

  // General Posture Analysis
  void _analyzeGeneralPosture(
    Pose pose,
  ) {
    final landmarks = _getLandmarks(
      pose,
    );
    final leftShoulderPt = landmarks['leftShoulder'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final leftHipPt = landmarks['leftHip'];
    final rightHipPt = landmarks['rightHip'];
    final shoulderCenter = _midpoint(leftShoulderPt, rightShoulderPt);
    final hipCenter = _midpoint(leftHipPt, rightHipPt);
    final nosePt = landmarks['nose'];
    final earPt = landmarks['leftEar'] ?? landmarks['rightEar'] ?? nosePt;

    if (shoulderCenter == null || hipCenter == null || nosePt == null) {
      _applyFeedback(
        _neutralFeedback(
          label: 'Person not fully visible',
          voicePrompt:
              'Show your head, shoulders, and hips clearly so I can read your posture.',
        ),
      );
      return;
    }

    final scale = _referenceScale(landmarks);
    final corrections = <String>[];
    final highlights = <String>[];
    final referenceDown = Offset(hipCenter.dx, hipCenter.dy + scale);

    _spineAngle = _calculateAngle(
      shoulderCenter,
      hipCenter,
      referenceDown,
    );
    _shoulderAngle = leftShoulderPt != null && rightShoulderPt != null
        ? _calculateAngle(
            leftShoulderPt,
            shoulderCenter,
            rightShoulderPt,
          )
        : 180.0;
    _neckAngle = earPt != null
        ? _calculateAngle(
            earPt,
            shoulderCenter,
            hipCenter,
          )
        : 180.0;

    final shoulderTilt = leftShoulderPt != null && rightShoulderPt != null
        ? (leftShoulderPt.dy - rightShoulderPt.dy).abs() / scale
        : 0.0;
    final hipTilt = leftHipPt != null && rightHipPt != null
        ? (leftHipPt.dy - rightHipPt.dy).abs() / scale
        : 0.0;
    final trunkShift = (shoulderCenter.dx - hipCenter.dx).abs() / scale;
    final headShift =
        earPt != null ? (earPt.dx - shoulderCenter.dx).abs() / scale : 0.0;

    if (headShift > 0.40) {
      corrections.add('Bring your head back over your shoulders.');
    }
    if (trunkShift > 0.24) {
      corrections.add('Stack your ribs over your hips and stand taller.');
    }
    if (shoulderTilt > 0.18) {
      corrections.add('Level your shoulders and relax your upper traps.');
    }
    if (hipTilt > 0.16) {
      corrections.add('Balance your weight evenly through both legs.');
    }

    if (corrections.isEmpty) {
      highlights.add('Posture looks tall and balanced.');
    }

    _applyFeedback(
      _buildExerciseFeedback(
        successLabel: 'Good posture alignment',
        successVoice:
            'Keep your chest open, chin neutral, and weight evenly distributed.',
        corrections: corrections,
        highlights: highlights,
      ),
    );
  }

  // Squat Analysis
  void _analyzeSquat(
    Pose pose,
  ) {
    final landmarks = _getLandmarks(
      pose,
    );
    final leftHipPt = landmarks['leftHip'];
    final rightHipPt = landmarks['rightHip'];
    final leftKneePt = landmarks['leftKnee'];
    final rightKneePt = landmarks['rightKnee'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightAnklePt = landmarks['rightAnkle'];
    final leftShoulderPt = landmarks['leftShoulder'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final shoulderCenter = _midpoint(leftShoulderPt, rightShoulderPt);
    final hipCenter = _midpoint(leftHipPt, rightHipPt);
    final ankleCenter = _midpoint(leftAnklePt, rightAnklePt);

    if (shoulderCenter == null ||
        hipCenter == null ||
        ankleCenter == null ||
        leftKneePt == null ||
        rightKneePt == null) {
      _applyFeedback(
        _neutralFeedback(
          label: 'Position yourself in frame',
          voicePrompt:
              'Show your shoulders, hips, knees, and ankles for squat analysis.',
        ),
      );
      return;
    }

    final scale = _referenceScale(landmarks);
    final kneeAngle = _averageValue([
          leftHipPt != null && leftAnklePt != null
              ? _calculateAngle(leftHipPt, leftKneePt, leftAnklePt)
              : null,
          rightHipPt != null && rightAnklePt != null
              ? _calculateAngle(rightHipPt, rightKneePt, rightAnklePt)
              : null,
        ]) ??
        180.0;
    final hipAngle = _averageValue([
          leftShoulderPt != null && leftHipPt != null
              ? _calculateAngle(leftShoulderPt, leftHipPt, leftKneePt)
              : null,
          rightShoulderPt != null && rightHipPt != null
              ? _calculateAngle(rightShoulderPt, rightHipPt, rightKneePt)
              : null,
        ]) ??
        180.0;

    _neckAngle = kneeAngle;
    _spineAngle = hipAngle;
    _shoulderAngle = leftShoulderPt != null && rightShoulderPt != null
        ? _calculateAngle(leftShoulderPt, shoulderCenter, rightShoulderPt)
        : 180.0;

    final corrections = <String>[];
    final highlights = <String>[];
    final leftTrack =
        leftAnklePt != null ? (leftKneePt.dx - leftAnklePt.dx).abs() / scale : 0.0;
    final rightTrack =
        rightAnklePt != null ? (rightKneePt.dx - rightAnklePt.dx).abs() / scale : 0.0;
    final trunkShift = (shoulderCenter.dx - ankleCenter.dx).abs() / scale;

    if (kneeAngle > 145) {
      corrections.add('Sink a little deeper by bending your knees more.');
    } else if (kneeAngle < 80) {
      highlights.add('Squat depth looks strong.');
    }
    if (max(leftTrack, rightTrack) > 0.46) {
      corrections.add('Track your knees over the middle of each foot.');
    }
    if (hipAngle < 138 || trunkShift > 0.82) {
      corrections.add('Keep your chest prouder and your spine more neutral.');
    }

    _applyFeedback(
      _buildExerciseFeedback(
        successLabel: 'Good squat mechanics',
        successVoice:
            'Keep driving through the feet and stay balanced through the whole rep.',
        corrections: corrections,
        highlights: highlights,
      ),
    );
  }

  // Push-Up Analysis
  void _analyzePushUp(
    Pose pose,
  ) {
    final landmarks = _getLandmarks(
      pose,
    );
    final leftShoulderPt = landmarks['leftShoulder'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final leftElbowPt = landmarks['leftElbow'];
    final rightElbowPt = landmarks['rightElbow'];
    final leftWristPt = landmarks['leftWrist'];
    final rightWristPt = landmarks['rightWrist'];
    final leftHipPt = landmarks['leftHip'];
    final rightHipPt = landmarks['rightHip'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightAnklePt = landmarks['rightAnkle'];

    if (leftShoulderPt == null ||
        leftElbowPt == null ||
        leftWristPt == null ||
        leftHipPt == null ||
        leftAnklePt == null) {
      _applyFeedback(
        _neutralFeedback(
          label: 'Position yourself in frame',
          voicePrompt:
              'Show your shoulders, elbows, hips, and ankles for push-up analysis.',
        ),
      );
      return;
    }

    final scale = _referenceScale(landmarks);
    final armAngle = _averageValue([
          _calculateAngle(leftShoulderPt, leftElbowPt, leftWristPt),
          rightShoulderPt != null && rightElbowPt != null && rightWristPt != null
              ? _calculateAngle(rightShoulderPt, rightElbowPt, rightWristPt)
              : null,
        ]) ??
        180.0;
    final bodyLineOffset = rightShoulderPt != null &&
            rightHipPt != null &&
            rightAnklePt != null
        ? _averageValue([
              _distanceToLine(leftHipPt, leftShoulderPt, leftAnklePt) / scale,
              _distanceToLine(rightHipPt, rightShoulderPt, rightAnklePt) / scale,
            ]) ??
            0.0
        : _distanceToLine(leftHipPt, leftShoulderPt, leftAnklePt) / scale;
    final wristStack = _averageValue([
          (leftWristPt.dx - leftShoulderPt.dx).abs() / scale,
          rightWristPt != null && rightShoulderPt != null
              ? (rightWristPt.dx - rightShoulderPt.dx).abs() / scale
              : null,
        ]) ??
        0.0;

    _shoulderAngle = armAngle;
    _spineAngle = 180 - (bodyLineOffset * 100).clamp(0, 90);

    final corrections = <String>[];
    final highlights = <String>[];

    if (armAngle > 145) {
      corrections.add('Lower your chest a little more with control.');
    } else if (armAngle < 95) {
      highlights.add('Push-up depth looks strong.');
    }
    if (bodyLineOffset > 0.24) {
      corrections.add('Keep your body in one straight line and brace your core.');
    }
    if (wristStack > 0.68) {
      corrections.add('Stack your wrists more directly under your shoulders.');
    }

    _applyFeedback(
      _buildExerciseFeedback(
        successLabel: 'Good push-up alignment',
        successVoice:
            'Stay tight through the core and press the floor away evenly.',
        corrections: corrections,
        highlights: highlights,
      ),
    );
  }

  // Plank Analysis
  void _analyzePlank(
    Pose pose,
  ) {
    final landmarks = _getLandmarks(
      pose,
    );
    final leftShoulderPt = landmarks['leftShoulder'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final leftHipPt = landmarks['leftHip'];
    final rightHipPt = landmarks['rightHip'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightAnklePt = landmarks['rightAnkle'];

    if (leftShoulderPt == null || leftHipPt == null || leftAnklePt == null) {
      _applyFeedback(
        _neutralFeedback(
          label: 'Position yourself in frame',
          voicePrompt:
              'Show your shoulders, hips, and ankles for plank analysis.',
        ),
      );
      return;
    }

    final scale = _referenceScale(landmarks);
    final alignmentAngle = _averageValue([
          _calculateAngle(leftShoulderPt, leftHipPt, leftAnklePt),
          rightShoulderPt != null && rightHipPt != null && rightAnklePt != null
              ? _calculateAngle(rightShoulderPt, rightHipPt, rightAnklePt)
              : null,
        ]) ??
        180.0;
    final bodyLineOffset = rightShoulderPt != null &&
            rightHipPt != null &&
            rightAnklePt != null
        ? _averageValue([
              _distanceToLine(leftHipPt, leftShoulderPt, leftAnklePt) / scale,
              _distanceToLine(rightHipPt, rightShoulderPt, rightAnklePt) / scale,
            ]) ??
            0.0
        : _distanceToLine(leftHipPt, leftShoulderPt, leftAnklePt) / scale;
    final levelError = _averageValue([
          rightShoulderPt != null
              ? (leftShoulderPt.dy - rightShoulderPt.dy).abs() / scale
              : null,
          rightHipPt != null ? (leftHipPt.dy - rightHipPt.dy).abs() / scale : null,
        ]) ??
        0.0;

    _spineAngle = alignmentAngle;

    final corrections = <String>[];
    final highlights = <String>[];

    if (alignmentAngle < 158 || bodyLineOffset > 0.22) {
      corrections.add('Keep your shoulders, hips, and ankles in one long line.');
    }
    if (levelError > 0.18) {
      corrections.add('Level your shoulders and hips so the plank stays square.');
    }
    if (corrections.isEmpty) {
      highlights.add('Plank alignment looks solid.');
    }

    _applyFeedback(
      _buildExerciseFeedback(
        successLabel: 'Good plank position',
        successVoice:
            'Keep squeezing your glutes and brace your core as you breathe.',
        corrections: corrections,
        highlights: highlights,
      ),
    );
  }

  // Lunge Analysis
  void _analyzeLunge(
    Pose pose,
  ) {
    final landmarks = _getLandmarks(
      pose,
    );
    final leftHipPt = landmarks['leftHip'];
    final rightHipPt = landmarks['rightHip'];
    final leftKneePt = landmarks['leftKnee'];
    final rightKneePt = landmarks['rightKnee'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightAnklePt = landmarks['rightAnkle'];
    final leftShoulderPt = landmarks['leftShoulder'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final shoulderCenter = _midpoint(leftShoulderPt, rightShoulderPt);
    final hipCenter = _midpoint(leftHipPt, rightHipPt);

    if (leftHipPt == null ||
        rightHipPt == null ||
        leftKneePt == null ||
        rightKneePt == null ||
        leftAnklePt == null ||
        rightAnklePt == null ||
        shoulderCenter == null ||
        hipCenter == null) {
      _applyFeedback(
        _neutralFeedback(
          label: 'Position yourself in frame',
          voicePrompt: 'Show both legs and your torso clearly for lunge analysis.',
        ),
      );
      return;
    }

    final scale = _referenceScale(landmarks);
    final leftFrontAngle = _calculateAngle(leftHipPt, leftKneePt, leftAnklePt);
    final rightFrontAngle = _calculateAngle(rightHipPt, rightKneePt, rightAnklePt);
    final usingLeftFront = leftFrontAngle <= rightFrontAngle;
    final frontKneeAngle = usingLeftFront ? leftFrontAngle : rightFrontAngle;
    final frontKneePt = usingLeftFront ? leftKneePt : rightKneePt;
    final frontAnklePt = usingLeftFront ? leftAnklePt : rightAnklePt;
    final torsoShift = (shoulderCenter.dx - hipCenter.dx).abs() / scale;
    final hipTilt = (leftHipPt.dy - rightHipPt.dy).abs() / scale;

    _spineAngle = 180 - (torsoShift * 100).clamp(0, 90);
    _neckAngle = frontKneeAngle;

    final corrections = <String>[];
    final highlights = <String>[];

    if (frontKneeAngle > 122) {
      corrections.add('Lower a little deeper or lengthen your stance.');
    } else if (frontKneeAngle < 78) {
      highlights.add('Lunge depth looks strong.');
    }
    if ((frontKneePt.dx - frontAnklePt.dx).abs() / scale > 0.42) {
      corrections.add('Keep your front knee stacked more directly over the ankle.');
    }
    if (torsoShift > 0.30) {
      corrections.add('Keep your torso taller and chest more upright.');
    }
    if (hipTilt > 0.20) {
      corrections.add('Square your hips and stay balanced through both legs.');
    }

    _applyFeedback(
      _buildExerciseFeedback(
        successLabel: 'Good lunge alignment',
        successVoice:
            'Stay tall through the torso and push evenly through the floor.',
        corrections: corrections,
        highlights: highlights,
      ),
    );
  }

  // Deadlift Analysis
  void _analyzeDeadlift(
    Pose pose,
  ) {
    final landmarks = _getLandmarks(
      pose,
    );
    final leftShoulderPt = landmarks['leftShoulder'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final leftHipPt = landmarks['leftHip'];
    final rightHipPt = landmarks['rightHip'];
    final leftKneePt = landmarks['leftKnee'];
    final rightKneePt = landmarks['rightKnee'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightAnklePt = landmarks['rightAnkle'];

    if (leftShoulderPt == null ||
        leftHipPt == null ||
        leftKneePt == null ||
        leftAnklePt == null) {
      _applyFeedback(
        _neutralFeedback(
          label: 'Position yourself in frame',
          voicePrompt:
              'Show your shoulders, hips, knees, and ankles for deadlift analysis.',
        ),
      );
      return;
    }

    final scale = _referenceScale(landmarks);
    final backAngle = _averageValue([
          _calculateAngle(leftShoulderPt, leftHipPt, leftKneePt),
          rightShoulderPt != null && rightHipPt != null && rightKneePt != null
              ? _calculateAngle(rightShoulderPt, rightHipPt, rightKneePt)
              : null,
        ]) ??
        180.0;
    final kneeAngle = _averageValue([
          _calculateAngle(leftHipPt, leftKneePt, leftAnklePt),
          rightHipPt != null && rightKneePt != null && rightAnklePt != null
              ? _calculateAngle(rightHipPt, rightKneePt, rightAnklePt)
              : null,
        ]) ??
        180.0;
    final shoulderLevel = rightShoulderPt != null
        ? (leftShoulderPt.dy - rightShoulderPt.dy).abs() / scale
        : 0.0;

    _spineAngle = backAngle;
    _neckAngle = kneeAngle;

    final corrections = <String>[];
    final highlights = <String>[];

    if (backAngle < 138) {
      corrections.add('Flatten your back more and keep the spine neutral.');
    }
    if (kneeAngle < 102) {
      corrections.add('Raise your hips slightly so this stays a hip hinge.');
    } else if (kneeAngle > 176) {
      corrections.add('Unlock your knees a bit more and load the hips.');
    }
    if (shoulderLevel > 0.18) {
      corrections.add('Level your shoulders and keep tension even on both sides.');
    }
    if (corrections.isEmpty) {
      highlights.add('Deadlift hinge looks controlled.');
    }

    _applyFeedback(
      _buildExerciseFeedback(
        successLabel: 'Good deadlift setup',
        successVoice:
            'Keep your lats tight, chest proud, and drive through the floor.',
        corrections: corrections,
        highlights: highlights,
      ),
    );
  }

  // Overhead Press Analysis
  void _analyzeOverheadPress(
    Pose pose,
  ) {
    final landmarks = _getLandmarks(
      pose,
    );
    final leftShoulderPt = landmarks['leftShoulder'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final leftElbowPt = landmarks['leftElbow'];
    final rightElbowPt = landmarks['rightElbow'];
    final leftWristPt = landmarks['leftWrist'];
    final rightWristPt = landmarks['rightWrist'];
    final leftHipPt = landmarks['leftHip'];
    final rightHipPt = landmarks['rightHip'];
    final shoulderCenter = _midpoint(leftShoulderPt, rightShoulderPt);
    final hipCenter = _midpoint(leftHipPt, rightHipPt);
    final wristCenter = _midpoint(leftWristPt, rightWristPt);

    if (leftShoulderPt == null ||
        leftElbowPt == null ||
        leftWristPt == null ||
        shoulderCenter == null ||
        hipCenter == null ||
        wristCenter == null) {
      _applyFeedback(
        _neutralFeedback(
          label: 'Position yourself in frame',
          voicePrompt:
              'Show your shoulders, elbows, wrists, and hips for overhead press analysis.',
        ),
      );
      return;
    }

    final scale = _referenceScale(landmarks);
    final armAngle = _averageValue([
          _calculateAngle(leftShoulderPt, leftElbowPt, leftWristPt),
          rightShoulderPt != null && rightElbowPt != null && rightWristPt != null
              ? _calculateAngle(rightShoulderPt, rightElbowPt, rightWristPt)
              : null,
        ]) ??
        180.0;
    final wristStack = (wristCenter.dx - shoulderCenter.dx).abs() / scale;
    final torsoShift = (shoulderCenter.dx - hipCenter.dx).abs() / scale;
    final shoulderLevel = rightShoulderPt != null
        ? (leftShoulderPt.dy - rightShoulderPt.dy).abs() / scale
        : 0.0;

    _shoulderAngle = armAngle;
    _spineAngle = 180 - (torsoShift * 100).clamp(0, 90);

    final corrections = <String>[];
    final highlights = <String>[];

    if (armAngle < 154) {
      corrections.add('Finish the press by extending the elbows fully overhead.');
    } else {
      highlights.add('Overhead lockout looks strong.');
    }
    if (wristStack > 0.40) {
      corrections.add('Stack your wrists more directly over the shoulders.');
    }
    if (torsoShift > 0.26) {
      corrections.add('Brace your core and avoid leaning your torso back.');
    }
    if (shoulderLevel > 0.18) {
      corrections.add('Keep both shoulders level as you press.');
    }

    _applyFeedback(
      _buildExerciseFeedback(
        successLabel: 'Good overhead press alignment',
        successVoice:
            'Keep your ribs down, press straight up, and stay tall through the torso.',
        corrections: corrections,
        highlights: highlights,
      ),
    );
  }

  // Pull-Up Analysis
  void _analyzePullUp(
    Pose pose,
  ) {
    final landmarks = _getLandmarks(
      pose,
    );
    final leftShoulderPt = landmarks['leftShoulder'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final leftElbowPt = landmarks['leftElbow'];
    final rightElbowPt = landmarks['rightElbow'];
    final leftWristPt = landmarks['leftWrist'];
    final rightWristPt = landmarks['rightWrist'];
    final leftHipPt = landmarks['leftHip'];
    final rightHipPt = landmarks['rightHip'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightAnklePt = landmarks['rightAnkle'];

    if (leftShoulderPt == null ||
        leftElbowPt == null ||
        leftWristPt == null ||
        leftHipPt == null) {
      _applyFeedback(
        _neutralFeedback(
          label: 'Position yourself in frame',
          voicePrompt:
              'Show your shoulders, elbows, hips, and legs for pull-up analysis.',
        ),
      );
      return;
    }

    final scale = _referenceScale(landmarks);
    final armAngle = _averageValue([
          _calculateAngle(leftShoulderPt, leftElbowPt, leftWristPt),
          rightShoulderPt != null && rightElbowPt != null && rightWristPt != null
              ? _calculateAngle(rightShoulderPt, rightElbowPt, rightWristPt)
              : null,
        ]) ??
        180.0;
    final swingOffset = rightShoulderPt != null &&
            rightHipPt != null &&
            rightAnklePt != null &&
            leftAnklePt != null
        ? _averageValue([
              _distanceToLine(leftHipPt, leftShoulderPt, leftAnklePt) / scale,
              _distanceToLine(rightHipPt, rightShoulderPt, rightAnklePt) / scale,
            ]) ??
            0.0
        : 0.0;
    final shoulderLevel = rightShoulderPt != null
        ? (leftShoulderPt.dy - rightShoulderPt.dy).abs() / scale
        : 0.0;

    _shoulderAngle = armAngle;
    _spineAngle = 180 - (swingOffset * 100).clamp(0, 90);

    final corrections = <String>[];
    final highlights = <String>[];

    if (armAngle > 82) {
      corrections.add('Pull higher so the chin clears the bar.');
    } else if (armAngle < 32) {
      highlights.add('Pull-up range of motion looks strong.');
    }
    if (swingOffset > 0.24) {
      corrections.add('Reduce swing and keep your body quieter through the rep.');
    }
    if (shoulderLevel > 0.18) {
      corrections.add('Keep your shoulders level as you pull.');
    }

    _applyFeedback(
      _buildExerciseFeedback(
        successLabel: 'Good pull-up control',
        successVoice:
            'Stay tight through the trunk and drive the elbows down smoothly.',
        corrections: corrections,
        highlights: highlights,
      ),
    );
  }

  // Bridge Analysis
  void _analyzeBridge(
    Pose pose,
  ) {
    final landmarks = _getLandmarks(
      pose,
    );
    final leftShoulderPt = landmarks['leftShoulder'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final leftHipPt = landmarks['leftHip'];
    final rightHipPt = landmarks['rightHip'];
    final leftKneePt = landmarks['leftKnee'];
    final rightKneePt = landmarks['rightKnee'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightAnklePt = landmarks['rightAnkle'];

    if (leftShoulderPt == null ||
        leftHipPt == null ||
        leftKneePt == null ||
        leftAnklePt == null) {
      _applyFeedback(
        _neutralFeedback(
          label: 'Position yourself in frame',
          voicePrompt:
              'Show your shoulders, hips, knees, and ankles for bridge analysis.',
        ),
      );
      return;
    }

    final scale = _referenceScale(landmarks);
    final hipAngle = _averageValue([
          _calculateAngle(leftShoulderPt, leftHipPt, leftKneePt),
          rightShoulderPt != null && rightHipPt != null && rightKneePt != null
              ? _calculateAngle(rightShoulderPt, rightHipPt, rightKneePt)
              : null,
        ]) ??
        180.0;
    final kneeStack = _averageValue([
          (leftKneePt.dx - leftAnklePt.dx).abs() / scale,
          rightKneePt != null && rightAnklePt != null
              ? (rightKneePt.dx - rightAnklePt.dx).abs() / scale
              : null,
        ]) ??
        0.0;
    final levelError = _averageValue([
          rightShoulderPt != null
              ? (leftShoulderPt.dy - rightShoulderPt.dy).abs() / scale
              : null,
          rightHipPt != null ? (leftHipPt.dy - rightHipPt.dy).abs() / scale : null,
        ]) ??
        0.0;

    _spineAngle = hipAngle;
    _neckAngle = kneeStack * 100;

    final corrections = <String>[];
    final highlights = <String>[];

    if (hipAngle < 142) {
      corrections.add('Drive through your heels and lift the hips a little higher.');
    } else {
      highlights.add('Bridge height looks strong.');
    }
    if (kneeStack > 0.44) {
      corrections.add('Keep your knees stacked more directly over your ankles.');
    }
    if (levelError > 0.20) {
      corrections.add('Keep your shoulders and hips level from side to side.');
    }

    _applyFeedback(
      _buildExerciseFeedback(
        successLabel: 'Good bridge alignment',
        successVoice:
            'Squeeze the glutes and keep the ribs quiet as you hold the bridge.',
        corrections: corrections,
        highlights: highlights,
      ),
    );
  }

  // Mountain Climber Analysis
  void _analyzeMountainClimber(
    Pose pose,
  ) {
    final landmarks = _getLandmarks(
      pose,
    );
    final leftShoulderPt = landmarks['leftShoulder'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final leftHipPt = landmarks['leftHip'];
    final rightHipPt = landmarks['rightHip'];
    final leftKneePt = landmarks['leftKnee'];
    final rightKneePt = landmarks['rightKnee'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightAnklePt = landmarks['rightAnkle'];
    final leftElbowPt = landmarks['leftElbow'];
    final rightElbowPt = landmarks['rightElbow'];

    if (leftShoulderPt == null ||
        leftHipPt == null ||
        leftKneePt == null ||
        leftAnklePt == null) {
      _applyFeedback(
        _neutralFeedback(
          label: 'Position yourself in frame',
          voicePrompt:
              'Show your shoulders, hips, knees, and ankles for mountain climber analysis.',
        ),
      );
      return;
    }

    final scale = _referenceScale(landmarks);
    final alignmentAngle = _averageValue([
          _calculateAngle(leftShoulderPt, leftHipPt, leftAnklePt),
          rightShoulderPt != null && rightHipPt != null && rightAnklePt != null
              ? _calculateAngle(rightShoulderPt, rightHipPt, rightAnklePt)
              : null,
        ]) ??
        180.0;
    final bodyLineOffset = rightShoulderPt != null &&
            rightHipPt != null &&
            rightAnklePt != null
        ? _averageValue([
              _distanceToLine(leftHipPt, leftShoulderPt, leftAnklePt) / scale,
              _distanceToLine(rightHipPt, rightShoulderPt, rightAnklePt) / scale,
            ]) ??
            0.0
        : _distanceToLine(leftHipPt, leftShoulderPt, leftAnklePt) / scale;
    final kneeDrive = _averageValue([
          leftElbowPt != null ? _distance(leftKneePt, leftElbowPt) / scale : null,
          rightKneePt != null && rightElbowPt != null
              ? _distance(rightKneePt, rightElbowPt) / scale
              : null,
        ]) ??
        10.0;
    final levelError = _averageValue([
          rightShoulderPt != null
              ? (leftShoulderPt.dy - rightShoulderPt.dy).abs() / scale
              : null,
          rightHipPt != null ? (leftHipPt.dy - rightHipPt.dy).abs() / scale : null,
        ]) ??
        0.0;

    _spineAngle = alignmentAngle;
    _neckAngle = max(0, 200 - (kneeDrive * 50));

    final corrections = <String>[];
    final highlights = <String>[];

    if (alignmentAngle < 158 || bodyLineOffset > 0.24) {
      corrections.add('Keep the plank line strong while you drive the knees.');
    }
    if (kneeDrive > 1.65) {
      corrections.add('Drive each knee a little closer toward the chest.');
    } else {
      highlights.add('Knee drive looks active and controlled.');
    }
    if (levelError > 0.20) {
      corrections.add('Keep your shoulders and hips level as you switch legs.');
    }

    _applyFeedback(
      _buildExerciseFeedback(
        successLabel: 'Good mountain climber control',
        successVoice:
            'Keep the core braced and move the knees fast without losing body line.',
        corrections: corrections,
        highlights: highlights,
      ),
    );
  }
  // Transform ML kit image coordinates (x,y) to widget coordinates for drawing overlay
  // This mapping is approximate and works well with typical CameraPreview sizes.
  // It assumes the preview is fit into the available widget bounds maintaining aspect ratio.
  Offset _transformPoint(
    Offset point,
    Size widgetSize,
  ) {
    if (_imageSize ==
        null) {
      return Offset.zero;
    }

    final imageW = _imageSize!.width;
    final imageH = _imageSize!.height;
    // CameraPreview uses device orientation; approximation: scaleX/scaleY
    final scaleX =
        widgetSize.width /
        imageW;
    final scaleY =
        widgetSize.height /
        imageH;

    // Choose the smaller scale to preserve aspect ratio, then center
    final scale = min(
      scaleX,
      scaleY,
    );

    final displayW =
        imageW *
        scale;
    final displayH =
        imageH *
        scale;

    final dx =
        (widgetSize.width -
            displayW) /
        2;
    final dy =
        (widgetSize.height -
            displayH) /
        2;

    // MLKit coordinates origin is top-left of image; so map directly with scale
    double x =
        point.dx *
            scale +
        dx;
    final y =
        point.dy *
            scale +
        dy;

    if (_isFrontCamera) {
      x =
          widgetSize.width -
          x;
    }

    return Offset(
      x,
      y,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final controller = _cameraController;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          '${widget.exerciseType.name} Analysis',
        ),
        backgroundColor: Colors.indigo,
      ),
      body:
          controller ==
                  null ||
              !controller.value.isInitialized
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : LayoutBuilder(
              builder:
                  (
                    context,
                    constraints,
                  ) {
                    final widgetSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(
                          controller,
                        ),
                        // Overlay painter: skeleton + angles
                        if (_lastPose !=
                            null)
                          CustomPaint(
                            painter: _PosePainter(
                              pose: _lastPose!,
                              transformPoint:
                                  (
                                    Offset p,
                                  ) => _transformPoint(
                                    p,
                                    widgetSize,
                                  ),
                              neckAngle: _neckAngle,
                              shoulderAngle: _shoulderAngle,
                              spineAngle: _spineAngle,
                            ),
                          ),
                        // UI: angles and label
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Exercise Instructions
                              Container(
                                padding: const EdgeInsets.all(
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          widget.exerciseType.icon,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                        const SizedBox(
                                          width: 8,
                                        ),
                                        Expanded(
                                          child: Text(
                                            widget.exerciseType.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    Text(
                                      widget.exerciseType.instructions,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 12,
                              ),
                              // Analysis Feedback
                              Container(
                                padding: const EdgeInsets.all(
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(
                                    10,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Angle: ${_spineAngle.toStringAsFixed(1)} deg',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 6,
                                    ),
                                    Text(
                                      _postureLabel,
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 6,
                                    ),
                                    Text(
                                      'Camera: $_cameraGuidance',
                                      style: const TextStyle(
                                        color: Colors.lightBlueAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(
            context,
          );
          try {
            // toggle camera direction (if multiple cameras)
            final cameras = await availableCameras();
            if (cameras.length <
                2) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Only one camera available',
                  ),
                ),
              );
              return;
            }
            final current = _cameraController!.description;
            final newCam = cameras.firstWhere(
              (
                c,
              ) =>
                  c.lensDirection !=
                  current.lensDirection,
              orElse: () => cameras.first,
            );
            await _cameraController!.stopImageStream();
            await _cameraController!.dispose();

            _cameraController = CameraController(
              newCam,
              ResolutionPreset.medium,
              imageFormatGroup: ImageFormatGroup.nv21,
              enableAudio: false,
            );
            _isFrontCamera =
                newCam.lensDirection ==
                CameraLensDirection.front;
            await _cameraController!.initialize();
            await _cameraController!.startImageStream(
              _processCameraImage,
            );
            if (mounted) {
              setState(
                () {},
              );
            }
          } catch (
            e
          ) {
            debugPrint(
              'Error switching camera: $e',
            );
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Error switching camera: $e',
                  ),
                ),
              );
            }
          }
        },
        child: const Icon(
          Icons.cameraswitch,
        ),
      ),
    );
  }
}

// Custom painter to draw landmarks and connections
class _PosePainter
    extends
        CustomPainter {
  final Pose pose;
  final Offset Function(
    Offset,
  )
  transformPoint;
  final double neckAngle, shoulderAngle, spineAngle;

  _PosePainter({
    required this.pose,
    required this.transformPoint,
    required this.neckAngle,
    required this.shoulderAngle,
    required this.spineAngle,
  });

  final Paint _landmarkPaint = Paint()
    ..style = PaintingStyle.fill
    ..strokeWidth = 4.0
    ..color = Colors.greenAccent;

  final Paint _linePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = Colors.greenAccent;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    // draw common landmarks
    const pairs = [
      // torso
      [
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
      ],
      [
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
      ],
      [
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftHip,
      ],
      [
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightHip,
      ],
      // arms
      [
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
      ],
      [
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist,
      ],
      [
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
      ],
      [
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
      ],
      // legs (optional)
      [
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
      ],
      [
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
      ],
      [
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
      ],
      [
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle,
      ],
      // head
      [
        PoseLandmarkType.nose,
        PoseLandmarkType.leftEyeInner,
      ],
      [
        PoseLandmarkType.nose,
        PoseLandmarkType.rightEyeInner,
      ],
    ];

    for (final p in pairs) {
      final a = pose.landmarks[p[0]];
      final b = pose.landmarks[p[1]];
      if (a ==
              null ||
          b ==
              null) {
        continue;
      }
      final pa = transformPoint(
        Offset(
          a.x,
          a.y,
        ),
      );
      final pb = transformPoint(
        Offset(
          b.x,
          b.y,
        ),
      );
      canvas.drawLine(
        pa,
        pb,
        _linePaint,
      );
    }

    // draw all visible points
    for (final entry in pose.landmarks.entries) {
      final lm = entry.value;
      final point = transformPoint(
        Offset(
          lm.x,
          lm.y,
        ),
      );
      canvas.drawCircle(
        point,
        3.5,
        _landmarkPaint,
      );
    }

    // draw angle texts near shoulders/hips
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    final tp = TextPainter(
      textDirection: TextDirection.ltr,
    );
    if (leftShoulder !=
        null) {
      final p = transformPoint(
        Offset(
          leftShoulder.x,
          leftShoulder.y,
        ),
      );
      tp.text = TextSpan(
        text: '${neckAngle.toStringAsFixed(1)} deg',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(
        canvas,
        p +
            const Offset(
              8,
              -8,
            ),
      );
    }
    if (leftHip !=
        null) {
      final p = transformPoint(
        Offset(
          leftHip.x,
          leftHip.y,
        ),
      );
      tp.text = TextSpan(
        text: '${spineAngle.toStringAsFixed(1)} deg',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(
        canvas,
        p +
            const Offset(
              8,
              -8,
            ),
      );
    }
    if (nose !=
        null) {
      final p = transformPoint(
        Offset(
          nose.x,
          nose.y,
        ),
      );
      tp.text = TextSpan(
        text: '${shoulderAngle.toStringAsFixed(1)} deg',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      tp.layout();
      tp.paint(
        canvas,
        p +
            const Offset(
              8,
              -8,
            ),
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _PosePainter old,
  ) => true;
}

