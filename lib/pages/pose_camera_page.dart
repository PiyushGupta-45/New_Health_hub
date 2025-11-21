// lib/pages/pose_camera_page.dart

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart' as mlkit;
import 'package:permission_handler/permission_handler.dart';

class PoseCameraPage
    extends
        StatefulWidget {
  const PoseCameraPage({
    super.key,
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
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _isFrontCamera =
          selectedCamera.lensDirection == CameraLensDirection.front;

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
      final inputImageRotation = _rotationIntToImageRotation(rotation);

      // Store image size in the same orientation as the preview widget
      if (rotation == 90 || rotation == 270) {
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
    // Required landmarks (use whatever is available; prefer left-side for single-angle)
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final leftEar = pose.landmarks[PoseLandmarkType.leftEar];
    final rightEar = pose.landmarks[PoseLandmarkType.rightEar];

    // If some points are missing, bail safely
    if (leftShoulder ==
            null ||
        leftHip ==
            null ||
        nose ==
            null ||
        rightShoulder ==
            null) {
      setState(
        () {
          _postureLabel = "Person not fully visible";
        },
      );
      return;
    }

    // Convert to Offsets (image coordinate space)
    final leftShoulderPt = Offset(
      leftShoulder.x,
      leftShoulder.y,
    );
    final rightShoulderPt = Offset(
      rightShoulder.x,
      rightShoulder.y,
    );
    final leftHipPt = Offset(
      leftHip.x,
      leftHip.y,
    );
    final rightHipPt =
        rightHip !=
            null
        ? Offset(
            rightHip.x,
            rightHip.y,
          )
        : leftHipPt;
    final nosePt = Offset(
      nose.x,
      nose.y,
    );
    final earPt =
        leftEar !=
            null
        ? Offset(
            leftEar.x,
            leftEar.y,
          )
        : (rightEar !=
                  null
              ? Offset(
                  rightEar.x,
                  rightEar.y,
                )
              : nosePt);

    // Neck angle: ear/ nose -- shoulder -- hip  (approx neck/spine relationship)
    _neckAngle = _calculateAngle(
      earPt,
      leftShoulderPt,
      leftHipPt,
    );

    // Shoulder angle: leftShoulder -- rightShoulder -- nose (gives tilt across shoulders)
    _shoulderAngle = _calculateAngle(
      leftShoulderPt,
      rightShoulderPt,
      nosePt,
    );

    // Spine angle: leftShoulder -- leftHip -- rightHip
    _spineAngle = _calculateAngle(
      leftShoulderPt,
      leftHipPt,
      rightHipPt,
    );

    // Posture rules (tunable)
    String label = "Good Posture 🙂";

    // Slouch detection (smaller neck angle => more forward head/slouch)
    if (_neckAngle <
        150) {
      label = "Slouching 😣";
    }

    // Shoulder tilt detection
    final shoulderDiff =
        (leftShoulderPt.dy -
                rightShoulderPt.dy)
            .abs();
    if (shoulderDiff >
        20) {
      label = "Shoulder Tilt ⚠️";
    }

    // Severe slouch & tilt both
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
      x = widgetSize.width - x;
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
        title: const Text(
          'Live Posture Analysis',
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
                    final previewSize =
                        controller.value.previewSize ??
                        Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
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
                          child: Container(
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
                                  'Neck: ${_neckAngle.toStringAsFixed(1)}°',
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Shoulder: ${_shoulderAngle.toStringAsFixed(1)}°',
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Spine: ${_spineAngle.toStringAsFixed(1)}°',
                                  style: const TextStyle(
                                    color: Colors.white,
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
                                  ),
                                ),
                              ],
                            ),
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
                newCam.lensDirection == CameraLensDirection.front;
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
    // helper to draw if exists
    void drawPoint(
      PoseLandmarkType type,
    ) {
      final lm = pose.landmarks[type];
      if (lm ==
          null)
        return;
      final p = transformPoint(
        Offset(
          lm.x,
          lm.y,
        ),
      );
      canvas.drawCircle(
        p,
        4.0,
        _landmarkPaint,
      );
    }

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
