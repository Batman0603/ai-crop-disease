import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/services/crop_disease_inference_service.dart';
import 'package:frontend/services/image_preprocessing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Phase 4 ONNX inference smoke test', () async {
    final inference = CropDiseaseInferenceService();

    try {
      print('=== PHASE 4 INFERENCE TEST ===');

      print('Loading ONNX model...');
      await inference.load();

      expect(inference.isLoaded, isTrue);
      print('MODEL LOADED: YES');

      // Replace this path with a real plant image on your computer.
      final imageFile = File('/tmp/crop_test.jpg');

      expect(
        await imageFile.exists(),
        isTrue,
        reason: 'Put a real crop/plant image at /tmp/crop_test.jpg',
      );

      print('Preprocessing image...');
      final input = await ImagePreprocessingService.preprocessFile(imageFile);

      print('INPUT ELEMENTS: ${input.length}');
      expect(input.length, 3 * 224 * 224);

      print('Running ONNX inference...');
      final prediction = await inference.predict(input);

      print('OUTPUT LOGITS/CLASSES: ${prediction.probabilities.length}');
      print('PREDICTED CLASS INDEX: ${prediction.classIndex}');
      print(
        'CONFIDENCE: ${prediction.confidence.toStringAsFixed(6)}',
      );

      final probabilitySum = prediction.probabilities.fold<double>(
        0.0,
        (sum, value) => sum + value,
      );

      print(
        'PROBABILITY SUM: ${probabilitySum.toStringAsFixed(6)}',
      );

      expect(prediction.probabilities.length, 25);
      expect(prediction.classIndex, inInclusiveRange(0, 24));
      expect(prediction.confidence, inInclusiveRange(0.0, 1.0));
      expect(probabilitySum, closeTo(1.0, 0.0001));

      print('=== PHASE 4 TEST PASSED ===');
    } finally {
      await inference.close();
    }
  });
}
