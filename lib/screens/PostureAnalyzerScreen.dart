import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class PostureAnalyzerScreen extends StatefulWidget {
  const PostureAnalyzerScreen({super.key});

  @override
  State<PostureAnalyzerScreen> createState() => _PostureAnalyzerScreenState();
}

class _PostureAnalyzerScreenState extends State<PostureAnalyzerScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.first;

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Camera error: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Posture Analyzer',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: _isCameraInitialized
          ? Stack(
              children: [
                CameraPreview(_cameraController!),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    padding: const EdgeInsets.all(12),
                    child: const Text(
                      'Camera active — ready for posture analysis',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.teal)),
    );
  }
}
