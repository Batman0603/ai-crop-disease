import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;
  bool _isPickingImage = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage) return;

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

  void _clearImage() {
    setState(() {
      _selectedImage = null;
    });
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
                onPressed: _isPickingImage
                    ? null
                    : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take a Photo'),
              ),

              const SizedBox(height: 12),

              // Gallery button
              OutlinedButton.icon(
                onPressed: _isPickingImage
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from Gallery'),
              ),

              if (_isPickingImage) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
              ],

              if (_selectedImage != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _isPickingImage ? null : _clearImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove Image'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.search),
                  label: const Text('Analyze Plant'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Disease analysis will be enabled in a later phase.',
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
