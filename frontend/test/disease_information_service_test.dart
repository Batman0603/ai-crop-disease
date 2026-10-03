import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/disease_information_service.dart';

void main() {
  test('returns disease information for a valid class index', () {
    final disease = DiseaseInformationService.getByClassIndex(0);

    expect(disease.classIndex, 0);
    expect(disease.diseaseName, isNotEmpty);
    expect(disease.crop, isNotEmpty);
    expect(disease.description, isNotEmpty);
  });

  test('throws for an unknown class index', () {
    expect(
      () => DiseaseInformationService.getByClassIndex(999),
      throwsStateError,
    );
  });
}
