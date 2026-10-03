class DiseaseInformation {
  const DiseaseInformation({
    required this.classIndex,
    required this.className,
    required this.crop,
    required this.diseaseName,
    required this.description,
    required this.symptoms,
    required this.treatment,
    required this.isHealthy,
  });

  final int classIndex;
  final String className;
  final String crop;
  final String diseaseName;
  final String description;
  final List<String> symptoms;
  final List<String> treatment;
  final bool isHealthy;
}
