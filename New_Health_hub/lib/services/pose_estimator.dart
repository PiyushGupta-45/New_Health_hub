import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class PoseEstimator {
  Interpreter? _interpreter;
  final int inputSize = 192;

  /// Load MoveNet model from assets
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('movenet_singlepose_lightning.tflite');
      print('✅ MoveNet model loaded successfully');
    } catch (e) {
      print('❌ Failed to load MoveNet model: $e');
    }
  }

  /// Estimate pose from an input image
  Future<List<List<double>>> estimatePose(img.Image image) async {
    if (_interpreter == null) {
      throw Exception("Interpreter not initialized. Call loadModel() first.");
    }

    // Preprocess the input image
    final input = _preprocess(image);

    // Prepare output buffer
    var output = List.generate(
      1,
      (_) => List.generate(17, (_) => List.filled(3, 0.0)),
    );

    // Run inference
    _interpreter!.run(input, output);

    // Convert to readable list of keypoints
    return output[0]
        .map<List<double>>((e) => e.map((v) => v.toDouble()).toList())
        .toList();
  }

  /// Image preprocessing: resize and normalize
  List<List<List<List>>> _preprocess(img.Image image) {
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    // 4D tensor: [1, height, width, channels]
    var buffer = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          final r = ((pixel.value >> 16) & 0xFF - 128) / 128.0;
          final g = ((pixel.value >> 8) & 0xFF - 128) / 128.0;
          final b = (pixel.value & 0xFF - 128) / 128.0;
          return [r, g, b];
        }),
      ),
    );

    return buffer;
  }

  /// Dispose interpreter when done
  void close() {
    _interpreter?.close();
  }
}

extension on img.Pixel {
  int get value {
    return (r.toInt() << 16) | (g.toInt() << 8) | b.toInt();
  }
}
