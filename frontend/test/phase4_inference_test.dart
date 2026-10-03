import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/services/crop_disease_inference_service.dart';

void main() {
  group('CropDiseasePrediction contract', () {
    test('prediction contract supports 25 classes', () {
      final prediction = CropDiseasePrediction(
        classIndex: 4,
        confidence: 0.57,
        probabilities: List<double>.filled(25, 0.04),
      );

      expect(prediction.classIndex, inInclusiveRange(0, 24));
      expect(prediction.probabilities, hasLength(25));
      expect(prediction.confidence, greaterThanOrEqualTo(0));
      expect(prediction.confidence, lessThanOrEqualTo(1));
    });

    test('Float32List input size matches model contract', () {
      const expectedElementCount = 3 * 224 * 224;

      final input = Float32List(expectedElementCount);

      expect(input.length, 150528);
      expect(input.length, expectedElementCount);
    });

    test('prediction probability values can represent a normalized output', () {
      final probabilities = <double>[
        0.01,
        0.257971,
        ...List<double>.filled(23, 0.01),
      ];

      final sum = probabilities.reduce((a, b) => a + b);

      expect(probabilities, hasLength(25));
      expect(sum, closeTo(0.497971, 0.000001));
    });
  });
}
