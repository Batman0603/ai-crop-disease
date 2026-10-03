import 'package:flutter_test/flutter_test.dart';

//import 'package:frontend/models/disease_information.dart';
import 'package:frontend/services/disease_information_service.dart';

void main() {
  group('DiseaseInformationService', () {
    test('contains information for all 25 model classes', () {
      for (var classIndex = 0; classIndex < 25; classIndex++) {
        final disease = DiseaseInformationService.getByClassIndex(classIndex);

        expect(disease.classIndex, classIndex);
        expect(disease.className, isNotEmpty);
        expect(disease.crop, isNotEmpty);
        expect(disease.diseaseName, isNotEmpty);
        expect(disease.description, isNotEmpty);
      }
    });

    test('contains exactly five healthy classes', () {
      final healthyIndices = <int>[];

      for (var classIndex = 0; classIndex < 25; classIndex++) {
        final disease = DiseaseInformationService.getByClassIndex(classIndex);

        if (disease.isHealthy) {
          healthyIndices.add(classIndex);
        }
      }

      expect(healthyIndices, equals([3, 7, 11, 14, 24]));
    });

    test('contains exactly twenty disease classes', () {
      var diseaseCount = 0;

      for (var classIndex = 0; classIndex < 25; classIndex++) {
        final disease = DiseaseInformationService.getByClassIndex(classIndex);

        if (!disease.isHealthy) {
          diseaseCount++;
        }
      }

      expect(diseaseCount, 20);
    });

    test('disease classes contain symptoms and management guidance', () {
      for (var classIndex = 0; classIndex < 25; classIndex++) {
        final disease = DiseaseInformationService.getByClassIndex(classIndex);

        if (!disease.isHealthy) {
          expect(
            disease.symptoms,
            isNotEmpty,
            reason: 'Class $classIndex has no symptoms.',
          );

          expect(
            disease.treatment,
            isNotEmpty,
            reason: 'Class $classIndex has no management guidance.',
          );
        }
      }
    });

    test('healthy classes do not contain disease symptoms', () {
      for (var classIndex = 0; classIndex < 25; classIndex++) {
        final disease = DiseaseInformationService.getByClassIndex(classIndex);

        if (disease.isHealthy) {
          expect(
            disease.symptoms,
            isEmpty,
            reason: 'Healthy class $classIndex has symptoms.',
          );

          expect(
            disease.treatment,
            isNotEmpty,
            reason: 'Healthy class $classIndex has no care guidance.',
          );
        }
      }
    });

    test('unknown class index throws StateError', () {
      expect(
        () => DiseaseInformationService.getByClassIndex(25),
        throwsStateError,
      );
    });

    test('known class 1 maps to Apple Black Rot', () {
      final disease = DiseaseInformationService.getByClassIndex(1);

      expect(disease.className, 'Apple___Black_rot');
      expect(disease.crop, 'Apple');
      expect(disease.diseaseName, 'Black Rot');
      expect(disease.isHealthy, isFalse);
    });

    test('known class 4 maps to Corn Gray Leaf Spot', () {
      final disease = DiseaseInformationService.getByClassIndex(4);

      expect(
        disease.className,
        'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot',
      );
      expect(disease.crop, 'Corn');
      expect(disease.diseaseName, 'Gray Leaf Spot');
      expect(disease.isHealthy, isFalse);
    });

    test('known class 24 maps to healthy tomato', () {
      final disease = DiseaseInformationService.getByClassIndex(24);

      expect(disease.className, 'Tomato___healthy');
      expect(disease.crop, 'Tomato');
      expect(disease.diseaseName, 'Healthy Tomato');
      expect(disease.isHealthy, isTrue);
    });
  });
}
