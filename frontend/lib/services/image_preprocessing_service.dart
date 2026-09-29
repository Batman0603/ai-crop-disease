import 'dart:io';

import 'package:image/image.dart' as img;

class ImagePreprocessingService {
  static const int inputWidth = 224;
  static const int inputHeight = 224;

  /// Decodes an image file and returns its resized RGB representation.
  ///
  /// The exact resize and normalization behavior must match the
  /// preprocessing used to train and export the model.
  Future<img.Image> decodeAndResize(File file) async {
    final bytes = await file.readAsBytes();

    final decodedImage = img.decodeImage(bytes);

    if (decodedImage == null) {
      throw const FormatException('Unable to decode the selected image.');
    }

    final orientedImage = img.bakeOrientation(decodedImage);

    final resizedImage = img.copyResize(
      orientedImage,
      width: inputWidth,
      height: inputHeight,
      interpolation: img.Interpolation.linear,
    );

    return img.copyResize(
      resizedImage,
      width: inputWidth,
      height: inputHeight,
      interpolation: img.Interpolation.nearest,
    );
  }
}
