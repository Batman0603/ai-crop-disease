import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Prepares a single image for the Crop Disease ONNX model.
///
/// Output:
/// - Float32List with 3 * 224 * 224 values
/// - Channel-first (CHW) order: all R values, then G, then B
/// - Batch dimension is added when constructing the ONNX input tensor.
class ImagePreprocessingService {
  ImagePreprocessingService._();

  static const int inputSize = 224;
  static const int resizeShortEdge = 256;

  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  /// Loads, orients, resizes, center-crops, normalizes, and packs an image.
  ///
  /// Throws [ArgumentError] if the image cannot be decoded or is too small.
  static Future<Float32List> preprocessFile(File file) async {
    final bytes = await file.readAsBytes();
    return preprocessBytes(bytes);
  }

  /// Same preprocessing as [preprocessFile], for already-loaded image bytes.
  static Float32List preprocessBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw ArgumentError('The selected file is not a supported image.');
    }

    // Apply EXIF orientation before resizing/cropping.
    final oriented = img.bakeOrientation(decoded);

    if (oriented.width <= 0 || oriented.height <= 0) {
      throw ArgumentError('The image has invalid dimensions.');
    }

    // torchvision Resize(256): resize the shorter edge to 256,
    // preserving the original aspect ratio.
    final int resizedWidth;
    final int resizedHeight;

    if (oriented.width <= oriented.height) {
      resizedWidth = resizeShortEdge;
      resizedHeight = (oriented.height * resizeShortEdge / oriented.width)
          .round();
    } else {
      resizedHeight = resizeShortEdge;
      resizedWidth = (oriented.width * resizeShortEdge / oriented.height)
          .round();
    }

    final resized = img.copyResize(
      oriented,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );

    // CenterCrop(224).
    final cropX = (resized.width - inputSize) ~/ 2;
    final cropY = (resized.height - inputSize) ~/ 2;

    if (cropX < 0 || cropY < 0) {
      throw ArgumentError('The resized image is smaller than the crop size.');
    }

    final cropped = img.copyCrop(
      resized,
      x: cropX,
      y: cropY,
      width: inputSize,
      height: inputSize,
    );

    // NCHW for a single image, with the batch dimension omitted:
    // [R plane][G plane][B plane].
    final planeSize = inputSize * inputSize;
    final output = Float32List(3 * planeSize);

    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = cropped.getPixel(x, y);
        final index = y * inputSize + x;

        final red = pixel.r.toDouble() / 255.0;
        final green = pixel.g.toDouble() / 255.0;
        final blue = pixel.b.toDouble() / 255.0;

        output[index] = (red - _mean[0]) / _std[0];
        output[planeSize + index] = (green - _mean[1]) / _std[1];
        output[2 * planeSize + index] = (blue - _mean[2]) / _std[2];
      }
    }

    if (output.length != 3 * inputSize * inputSize) {
      throw StateError('Unexpected preprocessed tensor length.');
    }

    return output;
  }
}
