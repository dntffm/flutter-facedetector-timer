import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

class BlinkDetector {
  late Interpreter _interpreter;

  BlinkDetector() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset('model_blink.tflite');
  }

  Future<double> runInference(TensorImage input) async {
    final outputBuffer = TensorBuffer.createFixedSize(
      _interpreter.getOutputTensor(0).shape,
      _interpreter.getOutputTensor(0).type,
    );

    _interpreter.run(input.buffer, outputBuffer.buffer);

    var result = outputBuffer.getDoubleList()[0];

    result = result * 100;
    result = double.parse(result.toStringAsFixed(1));

    return result;
  }
}
