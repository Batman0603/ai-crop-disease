import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/crop_disease_inference_service.dart';
import '../services/image_preprocessing_service.dart';

class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  final ImagePicker _picker = ImagePicker();
  final CropDiseaseInferenceService _inferenceService =
      CropDiseaseInferenceService();

  XFile? _selectedImage;
  bool _isPickingImage = false;
  bool _isAnalyzing = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage || _isAnalyzing) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      final XFile? image = await _picker.pickImage(source: source);

      if (!mounted) return;

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not select image: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  Future<void> _analyzeImage() async {
    final selectedImage = _selectedImage;

    if (selectedImage == null || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      debugPrint('========================================');
      debugPrint('STARTING CROP DISEASE INFERENCE');
      debugPrint('IMAGE: ${selectedImage.path}');

      // 1. Load the ONNX model.
      await _inferenceService.load();

      debugPrint('MODEL LOADED: ${_inferenceService.isLoaded ? "YES" : "NO"}');

      // 2. Preprocess the selected image.
      final Float32List input = await ImagePreprocessingService.preprocessFile(
        File(selectedImage.path),
      );

      debugPrint('INPUT: ${input.length}');

      // 3. Run ONNX inference.
      final prediction = await _inferenceService.predict(input);

      debugPrint('OUTPUT: ${prediction.probabilities.length}');
      debugPrint('CLASS INDEX: ${prediction.classIndex}');
      debugPrint('CONFIDENCE: ${prediction.confidence.toStringAsFixed(6)}');

      final probabilitySum = prediction.probabilities.fold<double>(
        0.0,
        (sum, probability) => sum + probability,
      );

      debugPrint('PROBABILITY SUM: ${probabilitySum.toStringAsFixed(6)}');
      debugPrint('========================================');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Inference successful — class ${prediction.classIndex}, '
            '${(prediction.confidence * 100).toStringAsFixed(1)}%',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('========================================');
      debugPrint('INFERENCE FAILED');
      debugPrint('ERROR: $error');
      debugPrint('STACK TRACE: $stackTrace');
      debugPrint('========================================');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disease analysis failed: $error'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  @override
  void dispose() {
    _inferenceService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Detect Disease'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Upload a plant image',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Take a clear photo of the affected plant leaf '
                'or choose an image from your gallery.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Image preview area
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: _selectedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No image selected',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your plant photo will appear here',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      )
                    : Image.file(
                        File(_selectedImage!.path),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text('Unable to display this image'),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 20),

              // Camera button
              FilledButton.icon(
                onPressed: (_isPickingImage || _isAnalyzing)
                    ? null
                    : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take a Photo'),
              ),

              const SizedBox(height: 12),

              // Gallery button
              OutlinedButton.icon(
                onPressed: (_isPickingImage || _isAnalyzing)
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from Gallery'),
              ),

              if (_isPickingImage || _isAnalyzing) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],

              if (_selectedImage != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: (_isPickingImage || _isAnalyzing)
                      ? null
                      : _clearImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove Image'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: (_isPickingImage || _isAnalyzing)
                      ? null
                      : _analyzeImage,
                  icon: const Icon(Icons.search),
                  label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Plant'),
                ),
                const SizedBox(height: 8),
                Text(
                  _isAnalyzing
                      ? 'Running the crop disease model...'
                      : 'Runs the on-device disease model.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
