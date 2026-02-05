// lib/pages/pose_camera_page.dart

import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart' as mlkit;
import 'package:permission_handler/permission_handler.dart';
import '../models/exercise_type.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(
      this,
    );
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    );
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
            null)
      return;
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
        if (mounted &&
            _lastPose ==
                null) {
          setState(
            () {
              _postureLabel = "Position yourself in frame";
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
        0)
      return 0.0;
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
    final nosePt = landmarks['nose'];
    final earPt =
        landmarks['leftEar'] ??
        landmarks['rightEar'] ??
        nosePt;

    if (leftShoulderPt ==
            null ||
        leftHipPt ==
            null ||
        nosePt ==
            null ||
        rightShoulderPt ==
            null) {
      setState(
        () {
          _postureLabel = "Person not fully visible";
        },
      );
      return;
    }

    _neckAngle = _calculateAngle(
      earPt!,
      leftShoulderPt,
      leftHipPt,
    );
    _shoulderAngle = _calculateAngle(
      leftShoulderPt,
      rightShoulderPt,
      nosePt,
    );
    _spineAngle = _calculateAngle(
      leftShoulderPt,
      leftHipPt,
      landmarks['rightHip'] ??
          leftHipPt,
    );

    String label = "Good Posture 🙂";
    final shoulderDiff =
        (leftShoulderPt.dy -
                rightShoulderPt.dy)
            .abs();

    if (_neckAngle <
        150) {
      label = "Slouching 😣";
    }
    if (shoulderDiff >
        20) {
      label = "Shoulder Tilt ⚠️";
    }
    if (_neckAngle <
            140 &&
        shoulderDiff >
            25) {
      label = "Bad posture — adjust back & shoulders";
    }

    setState(
      () {
        _postureLabel = label;
      },
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
    final leftKneePt = landmarks['leftKnee'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightKneePt = landmarks['rightKnee'];
    final rightAnklePt = landmarks['rightAnkle'];
    final leftShoulderPt = landmarks['leftShoulder'];

    if (leftHipPt ==
            null ||
        leftKneePt ==
            null ||
        leftAnklePt ==
            null) {
      setState(
        () {
          _postureLabel = "Position yourself in frame";
        },
      );
      return;
    }

    // Calculate knee angle (hip-knee-ankle)
    final kneeAngle = _calculateAngle(
      leftHipPt,
      leftKneePt,
      leftAnklePt,
    );
    // Calculate hip angle (shoulder-hip-knee)
    final hipAngle =
        leftShoulderPt !=
            null
        ? _calculateAngle(
            leftShoulderPt,
            leftHipPt,
            leftKneePt,
          )
        : 180.0;

    _spineAngle = hipAngle;
    _neckAngle = kneeAngle;

    String label = "Good Squat Form 💪";

    // Check depth (knee angle should be less than 90 degrees at bottom)
    if (kneeAngle >
        120) {
      label = "Go deeper! Knees should bend more ⬇️";
    } else if (kneeAngle <
        60) {
      label = "Excellent depth! 🎯";
    }

    // Check knee alignment (knees should track over toes)
    if (rightKneePt !=
            null &&
        rightAnklePt !=
            null) {
      final leftKneeX = leftKneePt.dx;
      final leftAnkleX = leftAnklePt.dx;
      final rightKneeX = rightKneePt.dx;
      final rightAnkleX = rightAnklePt.dx;

      if ((leftKneeX -
                      leftAnkleX)
                  .abs() >
              30 ||
          (rightKneeX -
                      rightAnkleX)
                  .abs() >
              30) {
        label = "Keep knees aligned over toes ⚠️";
      }
    }

    // Check back alignment
    if (hipAngle <
        150) {
      label = "Keep your back straighter ⚠️";
    }

    setState(
      () {
        _postureLabel = label;
      },
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
    final leftElbowPt = landmarks['leftElbow'];
    final leftWristPt = landmarks['leftWrist'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final leftHipPt = landmarks['leftHip'];

    if (leftShoulderPt ==
            null ||
        leftElbowPt ==
            null ||
        leftWristPt ==
            null ||
        leftHipPt ==
            null) {
      setState(
        () {
          _postureLabel = "Position yourself in frame";
        },
      );
      return;
    }

    // Calculate arm angle (shoulder-elbow-wrist)
    final armAngle = _calculateAngle(
      leftShoulderPt,
      leftElbowPt,
      leftWristPt,
    );
    // Calculate body alignment (shoulder-hip)
    final bodyAlignment =
        (leftShoulderPt.dy -
                leftHipPt.dy)
            .abs();

    _shoulderAngle = armAngle;
    _spineAngle = bodyAlignment;

    String label = "Good Push-Up Form 💪";

    // Check arm position (at bottom, arm angle should be around 90 degrees)
    if (armAngle >
        120) {
      label = "Go lower! Chest closer to ground ⬇️";
    } else if (armAngle <
        70) {
      label = "Excellent depth! 🎯";
    }

    // Check body alignment (shoulders and hips should be aligned)
    if (bodyAlignment >
        30) {
      label = "Keep body straight! No sagging ⚠️";
    }

    // Check shoulder alignment
    if (rightShoulderPt !=
        null) {
      final shoulderDiff =
          (leftShoulderPt.dy -
                  rightShoulderPt.dy)
              .abs();
      if (shoulderDiff >
          15) {
        label = "Keep shoulders level ⚠️";
      }
    }

    setState(
      () {
        _postureLabel = label;
      },
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
    final leftHipPt = landmarks['leftHip'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final rightHipPt = landmarks['rightHip'];

    if (leftShoulderPt ==
            null ||
        leftHipPt ==
            null ||
        leftAnklePt ==
            null) {
      setState(
        () {
          _postureLabel = "Position yourself in frame";
        },
      );
      return;
    }

    // Calculate body alignment angle (shoulder-hip-ankle should be straight)
    final alignmentAngle = _calculateAngle(
      leftShoulderPt,
      leftHipPt,
      leftAnklePt,
    );

    _spineAngle = alignmentAngle;

    String label = "Good Plank Form 💪";

    // Ideal plank: body should be straight (angle close to 180 degrees)
    if (alignmentAngle <
        160) {
      label = "Hips too high! Lower them ⬇️";
    } else if (alignmentAngle >
        190) {
      label = "Hips sagging! Lift them up ⬆️";
    } else {
      label = "Perfect alignment! 🎯";
    }

    // Check shoulder alignment
    if (rightShoulderPt !=
            null &&
        rightHipPt !=
            null) {
      final shoulderDiff =
          (leftShoulderPt.dy -
                  rightShoulderPt.dy)
              .abs();
      final hipDiff =
          (leftHipPt.dy -
                  rightHipPt.dy)
              .abs();

      if (shoulderDiff >
              15 ||
          hipDiff >
              15) {
        label = "Keep body level and straight ⚠️";
      }
    }

    setState(
      () {
        _postureLabel = label;
      },
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
    final leftKneePt = landmarks['leftKnee'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightHipPt = landmarks['rightHip'];
    final rightKneePt = landmarks['rightKnee'];
    final leftShoulderPt = landmarks['leftShoulder'];

    if (leftHipPt ==
            null ||
        leftKneePt ==
            null ||
        leftAnklePt ==
            null ||
        rightHipPt ==
            null ||
        rightKneePt ==
            null) {
      setState(
        () {
          _postureLabel = "Position yourself in frame";
        },
      );
      return;
    }

    // Calculate front knee angle
    final frontKneeAngle = _calculateAngle(
      leftHipPt,
      leftKneePt,
      leftAnklePt,
    );
    // Calculate torso alignment
    final torsoAngle =
        leftShoulderPt !=
            null
        ? _calculateAngle(
            leftShoulderPt,
            leftHipPt,
            rightHipPt,
          )
        : 180.0;

    _spineAngle = torsoAngle;
    _neckAngle = frontKneeAngle;

    String label = "Good Lunge Form 💪";

    // Front knee should be at 90 degrees
    if (frontKneeAngle >
        110) {
      label = "Step forward more! ⬇️";
    } else if (frontKneeAngle <
        80) {
      label = "Excellent depth! 🎯";
    }

    // Check if front knee is over ankle
    if ((leftKneePt.dx -
                leftAnklePt.dx)
            .abs() >
        30) {
      label = "Keep front knee over ankle ⚠️";
    }

    // Check torso alignment
    if (torsoAngle <
        170) {
      label = "Keep torso upright! ⚠️";
    }

    setState(
      () {
        _postureLabel = label;
      },
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
    final leftHipPt = landmarks['leftHip'];
    final leftKneePt = landmarks['leftKnee'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightShoulderPt = landmarks['rightShoulder'];

    if (leftShoulderPt ==
            null ||
        leftHipPt ==
            null ||
        leftKneePt ==
            null) {
      setState(
        () {
          _postureLabel = "Position yourself in frame";
        },
      );
      return;
    }

    // Calculate back angle (shoulder-hip-knee)
    final backAngle = _calculateAngle(
      leftShoulderPt,
      leftHipPt,
      leftKneePt,
    );
    // Calculate knee angle
    final kneeAngle =
        leftAnklePt !=
            null
        ? _calculateAngle(
            leftHipPt,
            leftKneePt,
            leftAnklePt,
          )
        : 180.0;

    _spineAngle = backAngle;
    _neckAngle = kneeAngle;

    String label = "Good Deadlift Form 💪";

    // Back should be relatively straight (angle > 150)
    if (backAngle <
        140) {
      label = "Keep back straighter! ⚠️";
    }

    // Check shoulder alignment
    if (rightShoulderPt !=
        null) {
      final shoulderDiff =
          (leftShoulderPt.dy -
                  rightShoulderPt.dy)
              .abs();
      if (shoulderDiff >
          15) {
        label = "Keep shoulders level ⚠️";
      }
    }

    setState(
      () {
        _postureLabel = label;
      },
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
    final leftElbowPt = landmarks['leftElbow'];
    final leftWristPt = landmarks['leftWrist'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final leftHipPt = landmarks['leftHip'];

    if (leftShoulderPt ==
            null ||
        leftElbowPt ==
            null ||
        leftWristPt ==
            null ||
        leftHipPt ==
            null) {
      setState(
        () {
          _postureLabel = "Position yourself in frame";
        },
      );
      return;
    }

    // Calculate arm angle
    final armAngle = _calculateAngle(
      leftShoulderPt,
      leftElbowPt,
      leftWristPt,
    );
    // Calculate torso alignment
    final torsoAngle = _calculateAngle(
      leftShoulderPt,
      leftHipPt,
      landmarks['rightHip'] ??
          leftHipPt,
    );

    _shoulderAngle = armAngle;
    _spineAngle = torsoAngle;

    String label = "Good Overhead Press Form 💪";

    // Check if arms are fully extended (angle close to 180)
    if (armAngle <
        160) {
      label = "Extend arms fully! ⬆️";
    } else {
      label = "Perfect extension! 🎯";
    }

    // Check torso alignment
    if (torsoAngle <
        170) {
      label = "Keep core engaged, back straight ⚠️";
    }

    // Check shoulder alignment
    if (rightShoulderPt !=
        null) {
      final shoulderDiff =
          (leftShoulderPt.dy -
                  rightShoulderPt.dy)
              .abs();
      if (shoulderDiff >
          15) {
        label = "Keep shoulders level ⚠️";
      }
    }

    setState(
      () {
        _postureLabel = label;
      },
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
    final leftElbowPt = landmarks['leftElbow'];
    final leftWristPt = landmarks['leftWrist'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final leftHipPt = landmarks['leftHip'];

    if (leftShoulderPt ==
            null ||
        leftElbowPt ==
            null ||
        leftWristPt ==
            null) {
      setState(
        () {
          _postureLabel = "Position yourself in frame";
        },
      );
      return;
    }

    // Calculate arm angle (at top, should be close to 0)
    final armAngle = _calculateAngle(
      leftShoulderPt,
      leftElbowPt,
      leftWristPt,
    );
    // Calculate body alignment
    final bodyAlignment =
        leftHipPt !=
            null
        ? (leftShoulderPt.dy -
                  leftHipPt.dy)
              .abs()
        : 0.0;

    _shoulderAngle = armAngle;
    _spineAngle = bodyAlignment;

    String label = "Good Pull-Up Form 💪";

    // At top position, arm angle should be small
    if (armAngle >
        60) {
      label = "Pull higher! Chin over bar ⬆️";
    } else if (armAngle <
        30) {
      label = "Excellent! Full range of motion 🎯";
    }

    // Check for kipping (body swinging)
    if (bodyAlignment >
        40) {
      label = "Avoid kipping! Keep body still ⚠️";
    }

    // Check shoulder alignment
    if (rightShoulderPt !=
        null) {
      final shoulderDiff =
          (leftShoulderPt.dy -
                  rightShoulderPt.dy)
              .abs();
      if (shoulderDiff >
          15) {
        label = "Keep shoulders level ⚠️";
      }
    }

    setState(
      () {
        _postureLabel = label;
      },
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
    final leftHipPt = landmarks['leftHip'];
    final leftKneePt = landmarks['leftKnee'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final rightHipPt = landmarks['rightHip'];

    if (leftShoulderPt ==
            null ||
        leftHipPt ==
            null ||
        leftKneePt ==
            null) {
      setState(
        () {
          _postureLabel = "Position yourself in frame";
        },
      );
      return;
    }

    // Calculate hip angle (shoulder-hip-knee)
    final hipAngle = _calculateAngle(
      leftShoulderPt,
      leftHipPt,
      leftKneePt,
    );
    // Calculate knee angle
    final kneeAngle =
        leftAnklePt !=
            null
        ? _calculateAngle(
            leftHipPt,
            leftKneePt,
            leftAnklePt,
          )
        : 180.0;

    _spineAngle = hipAngle;
    _neckAngle = kneeAngle;

    String label = "Good Bridge Form 💪";

    // Hip should be lifted (angle > 150)
    if (hipAngle <
        140) {
      label = "Lift hips higher! ⬆️";
    } else if (hipAngle >
        170) {
      label = "Perfect bridge! 🎯";
    }

    // Check alignment
    if (rightShoulderPt !=
            null &&
        rightHipPt !=
            null) {
      final shoulderDiff =
          (leftShoulderPt.dy -
                  rightShoulderPt.dy)
              .abs();
      final hipDiff =
          (leftHipPt.dy -
                  rightHipPt.dy)
              .abs();

      if (shoulderDiff >
              15 ||
          hipDiff >
              15) {
        label = "Keep body aligned ⚠️";
      }
    }

    setState(
      () {
        _postureLabel = label;
      },
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
    final leftHipPt = landmarks['leftHip'];
    final leftKneePt = landmarks['leftKnee'];
    final leftAnklePt = landmarks['leftAnkle'];
    final rightShoulderPt = landmarks['rightShoulder'];
    final rightHipPt = landmarks['rightHip'];

    if (leftShoulderPt ==
            null ||
        leftHipPt ==
            null ||
        leftKneePt ==
            null) {
      setState(
        () {
          _postureLabel = "Position yourself in frame";
        },
      );
      return;
    }

    // Calculate body alignment (shoulder-hip-ankle)
    final alignmentAngle =
        leftAnklePt !=
            null
        ? _calculateAngle(
            leftShoulderPt,
            leftHipPt,
            leftAnklePt,
          )
        : 180.0;
    // Calculate knee position relative to hip
    final kneePosition =
        (leftKneePt.dy -
        leftHipPt.dy);

    _spineAngle = alignmentAngle;
    _neckAngle = kneePosition.abs();

    String label = "Good Mountain Climber Form 💪";

    // Body should be in plank position (alignment close to 180)
    if (alignmentAngle <
        160) {
      label = "Keep body straight! Hips down ⬇️";
    } else if (alignmentAngle >
        190) {
      label = "Hips too high! Lower them ⬇️";
    }

    // Check if knee is being brought forward (mountain climber movement)
    if (kneePosition <
        -20) {
      label = "Good! Bring knee forward 🎯";
    }

    // Check alignment
    if (rightShoulderPt !=
            null &&
        rightHipPt !=
            null) {
      final shoulderDiff =
          (leftShoulderPt.dy -
                  rightShoulderPt.dy)
              .abs();
      final hipDiff =
          (leftHipPt.dy -
                  rightHipPt.dy)
              .abs();

      if (shoulderDiff >
              15 ||
          hipDiff >
              15) {
        label = "Keep body level ⚠️";
      }
    }

    setState(
      () {
        _postureLabel = label;
      },
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
        null)
      return Offset.zero;

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
                                        color: Colors.white.withOpacity(
                                          0.9,
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
                                      'Angle: ${_spineAngle.toStringAsFixed(1)}°',
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
          try {
            // toggle camera direction (if multiple cameras)
            final cameras = await availableCameras();
            if (cameras.length <
                2) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
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
              null)
        continue;
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
        text: '${neckAngle.toStringAsFixed(1)}°',
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
        text: '${spineAngle.toStringAsFixed(1)}°',
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
        text: '${shoulderAngle.toStringAsFixed(1)}°',
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
