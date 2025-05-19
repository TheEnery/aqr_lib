import 'package:image/image.dart';

import 'byte4_matrix.dart';

/// Internal representation of images.
///
/// Data is stored in the matrix of Uint32
/// that can be retrieved via double [] operator.
/// Each value represents LRGB pixel, where L is 8 least significant bits
/// and B is 8 most significant bits.
/// The constructors apply gamma decoding, so RGB values are linear.
/// L value is automatically calculated luminance.
/// The least significant bit can represent if
/// is pixel black(1) or white(0) after binarization.
/// Since AQR is rotation-independent, this representation doesn't handle
/// case when source is rotated relatively to expected orientation.
class LrgbMatrix extends Byte4Matrix {
  static const double gamma = 2.4;

  LrgbMatrix({required super.height, required super.width});

  factory LrgbMatrix.fromImage(Image image) {
    final matrix = LrgbMatrix(height: image.height, width: image.width);

    for (int x = 0; x < image.width; x++) {
      final column = matrix[x];
      for (int y = 0; y < image.height; y++) {
        final p = image.getPixel(x, y);
        column[y] = (p.luminance.toInt() << 0) |
            (p.r.toInt() << 8) |
            (p.g.toInt() << 16) |
            (p.b.toInt() << 24);
      }
    }

    return matrix;
  }

  // factory LrgbMatrix.fromCameraImage(CameraImage cameraImage) {
  //   if (cameraImage.format.group != ImageFormatGroup.yuv420) {
  //     throw UnsupportedError(
  //       'Only ${ImageFormatGroup.yuv420.name} format is supported, '
  //       'but ${cameraImage.format.group.name} received.',
  //     );
  //   }

  //   final height = cameraImage.height;
  //   final width = cameraImage.width;
  //   final matrix = LrgbMatrix(height: height, width: width);

  //   final yBuffer = cameraImage.planes[0].bytes;
  //   final uBuffer = cameraImage.planes[1].bytes;
  //   final vBuffer = cameraImage.planes[2].bytes;

  //   final yRowStride = cameraImage.planes[0].bytesPerRow;
  //   final yPixelStride = cameraImage.planes[0].bytesPerPixel!;

  //   final uvRowStride = cameraImage.planes[1].bytesPerRow;
  //   final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

  //   for (int w = 0; w < width; w++) {
  //     final uvw = w ~/ 2;

  //     final column = matrix[w];

  //     for (int h = 0; h < height; h++) {
  //       final uvh = h ~/ 2;

  //       final yIndex = (h * yRowStride) + (w * yPixelStride);
  //       final int y = yBuffer[yIndex];

  //       final uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);
  //       final int u = uBuffer[uvIndex];
  //       final int v = vBuffer[uvIndex];

  //       int r = (y + v * 1436 / 1024 - 179).round();
  //       int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
  //       int b = (y + u * 1814 / 1024 - 227).round();

  //       r = r.clamp(0, 255);
  //       g = g.clamp(0, 255);
  //       b = b.clamp(0, 255);

  //       // r = (pow(r / 255, gamma).clamp(0, 1) * 255).toInt();
  //       // g = (pow(g / 255, gamma).clamp(0, 1) * 255).toInt();
  //       // b = (pow(b / 255, gamma).clamp(0, 1) * 255).toInt();

  //       final l = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b).round();

  //       column[h] = (l << 0) | (r << 8) | (g << 16) | (b << 24);
  //     }
  //   }

  //   return matrix;
  // }
}

extension IntLrgbConverter on int {}
