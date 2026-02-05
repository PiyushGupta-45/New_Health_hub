import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class MoveNetService {
  late Interpreter interpreter;

  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset(
      'movenet_singlepose_lightning.tflite',  // your asset file
      options: InterpreterOptions()..threads = 2,
    );
  }

  /// input: preprocessed image data as Float32List (192x192x3, normalized)
  /// output: keypoints (17 x 3)
  List<List<double>> predict(Float32List input) {
    var inputShape = interpreter.getInputTensor(0).shape;
    var outputShape = interpreter.getOutputTensor(0).shape;

    // Create output buffer with proper shape [1, 1, 17, 3]
    var output = List.generate(
      outputShape[0],
      (_) => List.generate(
        outputShape[1],
        (_) => List.generate(
          outputShape[2],
          (_) => List.generate(outputShape[3], (_) => 0.0),
        ),
      ),
    );

    // Reshape input to match expected shape [1, 192, 192, 3]
    var reshapedInput = List.generate(
      inputShape[0],
      (i) => List.generate(
        inputShape[1],
        (j) => List.generate(
          inputShape[2],
          (k) => List.generate(
            inputShape[3],
            (l) {
              var index = i * inputShape[1] * inputShape[2] * inputShape[3] +
                  j * inputShape[2] * inputShape[3] +
                  k * inputShape[3] +
                  l;
              return index < input.length ? input[index] : 0.0;
            },
          ),
        ),
      ),
    );

    interpreter.run(reshapedInput, output);

    return output[0][0]
        .map<List<double>>((kp) => [kp[0], kp[1], kp[2]])
        .toList();
  }
}
