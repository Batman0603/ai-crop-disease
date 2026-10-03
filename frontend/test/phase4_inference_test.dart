import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/crop_disease_inference_service.dart';

void main() {
  group('Phase 4 ONNX inference service', () {
    test('uses the expected model contract', () {
      expect(
        CropDiseaseInferenceService.modelAsset,
        'assets/models/crop_disease_efficientnet_v2_s.onnx',
      );

      expect(CropDiseaseInferenceService.inputElementCount, 3 * 224 * 224);

      expect(CropDiseaseInferenceService.classCount, 25);
    });

    test('rejects an incorrectly sized input tensor', () async {
      final service = CropDiseaseInferenceService();

      expect(
        () => service.predict(Float32List(10)),
        throwsA(isA<StateError>()),
      );

      await service.close();
    });
  });
}
