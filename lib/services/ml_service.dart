// import 'package:flutter/services.dart' show rootBundle;
// import 'package:tflite_flutter/tflite_flutter.dart';

class MLService {
  // Interpreter? _interpreter;

  Future<void> loadModel() async {
    // final modelData = await rootBundle.load('assets/models/energy_predictor.tflite');
    // final data = modelData.buffer.asUint8List();
    // _interpreter = Interpreter.fromBuffer(data);
    // debugPrint("ML Model loading disabled for Web compatibility");
  }

  Future<double> forecastNextMonth(List<double> historyKWh) async {
    // if (_interpreter == null) {
    //   await loadModel();
    // }
    // final input = [historyKWh];
    // final output = List.filled(1, List.filled(1, 0.0));
    // _interpreter!.run(input, output);
    // return output[0][0];
    
    // Fallback Mock Prediction
    return 350.0;
  }
}
