import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:frontend/services/image_preprocessing_service.dart';

void main() {
  test('produces one normalized CHW float32 image tensor', () {
    // Solid RGB image, deliberately non-square to exercise resize/crop.
    final source = img.Image(width: 300, height: 400);

    img.fill(source, color: img.ColorRgb8(255, 0, 0));

    final encoded = Uint8List.fromList(img.encodePng(source));
    final tensor = ImagePreprocessingService.preprocessBytes(encoded);

    expect(tensor, hasLength(3 * 224 * 224));

    // For a pure red image:
    // R = (1.0 - 0.485) / 0.229
    // G = (0.0 - 0.456) / 0.224
    // B = (0.0 - 0.406) / 0.225
    const planeSize = 224 * 224;

    expect(tensor[0], closeTo((1.0 - 0.485) / 0.229, 0.0001));
    expect(tensor[planeSize], closeTo((0.0 - 0.456) / 0.224, 0.0001));
    expect(tensor[2 * planeSize], closeTo((0.0 - 0.406) / 0.225, 0.0001));
  });

  test('rejects invalid image bytes', () {
    expect(
      () => ImagePreprocessingService.preprocessBytes(
        Uint8List.fromList([1, 2, 3, 4]),
      ),
      throwsArgumentError,
    );
  });
}
