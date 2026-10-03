import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class CropDiseasePrediction {
  const CropDiseasePrediction({
    required this.classIndex,
    required this.confidence,
    required this.probabilities,
  });

  final int classIndex;

  /// Probability from 0.0 to 1.0.
  final double confidence;

  /// Softmax probabilities in model class-index order.
  final List<double> probabilities;
}

class CropDiseaseInferenceService {
  static const String modelAsset =
      'assets/models/crop_disease_efficientnet_v2_s.onnx';

  static const int inputElementCount = 3 * 224 * 224;
  static const int classCount = 25;

  final OnnxRuntime _runtime = OnnxRuntime();

  OrtSession? _session;

  bool get isLoaded => _session != null;

  /// Loads the ONNX model from the Flutter asset bundle.
  Future<void> load() async {
    if (_session != null) return;

    final session = await _runtime.createSessionFromAsset(modelAsset);

    if (!session.inputNames.contains('images')) {
      await session.close();
      throw StateError(
        'Model input "images" was not found. '
        'Available inputs: ${session.inputNames}',
      );
    }

    if (!session.outputNames.contains('logits')) {
      await session.close();
      throw StateError(
        'Model output "logits" was not found. '
        'Available outputs: ${session.outputNames}',
      );
    }

    _session = session;
  }

  /// Runs inference on a normalized RGB CHW tensor from preprocessing.
  ///
  /// Expected tensor length: 3 * 224 * 224.
  /// Expected model input shape: [1, 3, 224, 224].
  Future<CropDiseasePrediction> predict(Float32List inputData) async {
    final session = _session;

    if (session == null) {
      throw StateError('Model is not loaded. Call load() before predict().');
    }

    if (inputData.length != inputElementCount) {
      throw ArgumentError(
        'Expected $inputElementCount input values, '
        'received ${inputData.length}.',
      );
    }

    OrtValue? inputTensor;
    final outputTensors = <OrtValue>[];

    try {
      inputTensor = await OrtValue.fromList(inputData, [1, 3, 224, 224]);

      final outputs = await session.run({'images': inputTensor});

      outputTensors.addAll(outputs.values);

      final logitsTensor = outputs['logits'];

      if (logitsTensor == null) {
        throw StateError('Inference did not return the "logits" output.');
      }

      final rawValues = await logitsTensor.asFlattenedList();

      if (rawValues.length != classCount) {
        throw StateError(
          'Expected $classCount logits, received ${rawValues.length}.',
        );
      }

      final logits = rawValues
          .map((value) => (value as num).toDouble())
          .toList();
      final probabilities = _softmax(logits);

      var bestIndex = 0;

      for (var i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > probabilities[bestIndex]) {
          bestIndex = i;
        }
      }

      return CropDiseasePrediction(
        classIndex: bestIndex,
        confidence: probabilities[bestIndex],
        probabilities: probabilities,
      );
    } finally {
      if (inputTensor != null) {
        await inputTensor.dispose();
      }

      for (final tensor in outputTensors) {
        await tensor.dispose();
      }
    }
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);

    final exponentials = logits
        .map((value) => math.exp(value - maxLogit))
        .toList();

    final sum = exponentials.reduce((a, b) => a + b);

    return exponentials.map((value) => value / sum).toList();
  }

  /// Releases the native ONNX session.
  Future<void> close() async {
    final session = _session;
    _session = null;

    if (session != null) {
      await session.close();
    }
  }
}
