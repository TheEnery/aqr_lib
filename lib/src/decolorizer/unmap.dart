import 'dart:math';

import 'package:image/image.dart';

import '../core/byte4_matrix.dart';
import '../core/byte_matrix.dart';

num simplifiedDistance(Color rgb1, Color rgb2) {
  return (rgb1.r - rgb2.r).abs() +
      (rgb1.g - rgb2.g).abs() +
      (rgb1.b - rgb2.b).abs();
}

/// irrelevant
ByteMatrix unmap(Byte4Matrix image, List<Color> palette) {
  final data = ByteMatrix(height: image.height, width: image.width);
  for (int x = 0; x < image.width; x++) {
    for (int y = 0; y < image.height; y++) {
      final rgbList = image[x][y].to4ByteList();
      final rgb = ColorRgb8(rgbList[1], rgbList[2], rgbList[3]);

      num bestDistance = 0x7FFFFFFF;
      late Color bestColor;
      for (final color in palette) {
        final distance = simplifiedDistance(color, rgb);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestColor = color;
        }
      }

      data[x][y] = palette.indexOf(bestColor);
    }
  }

  return data;
}

/// L from 0 to 1, a from -1 to 1 and b from -1 to 1 (all represents percentage)
List<num> rgbToOklab(num R, num G, num B) {
  // Step 1: Convert sRGB to linear RGB
  R = R / 255.0;
  G = G / 255.0;
  B = B / 255.0;

  // Apply the sRGB to linear RGB conversion
  // This is the reverse of the sRGB gamma correction
  // Reference: https://en.wikipedia.org/wiki/SRGB#The_reverse_transformation
  // R = R <= 0.04045 ? R / 12.92 : pow((R + 0.055) / 1.055, 2.4);
  // G = G <= 0.04045 ? G / 12.92 : pow((G + 0.055) / 1.055, 2.4);
  // B = B <= 0.04045 ? B / 12.92 : pow((B + 0.055) / 1.055, 2.4);

  // Step 2: Convert linear RGB to LMS (cone response)
  final double l = 0.4122214708 * R + 0.5363325363 * G + 0.0514459929 * B;
  final double m = 0.2119034982 * R + 0.6806995451 * G + 0.1073969566 * B;
  final double s = 0.0883024619 * R + 0.2817188376 * G + 0.6299787005 * B;

  // Step 3: Apply nonlinear transformation to LMS
  final double lNonlinear = l > 0 ? pow(l, 1 / 3) as double : 0;
  final double mNonlinear = m > 0 ? pow(m, 1 / 3) as double : 0;
  final double sNonlinear = s > 0 ? pow(s, 1 / 3) as double : 0;

  // Step 4: Convert to OKLAB
  final double L = 0.2104542553 * lNonlinear +
      0.7936177850 * mNonlinear -
      0.0040720468 * sNonlinear;
  final double a = 1.9779984951 * lNonlinear -
      2.4285922050 * mNonlinear +
      0.4505937099 * sNonlinear;
  final double b = 0.0259040371 * lNonlinear +
      0.7827717662 * mNonlinear -
      0.8086757660 * sNonlinear;

  return [L, a / .4, b / .4];
}

/// Converts OKLab color to OKLCH color
///
/// Parameters:
/// - l: Lightness (0-1)
/// - a: Green-red component
/// - b: Blue-yellow component
///
/// Returns a list [l, c, h] where:
/// - l: Lightness (0-1)
/// - c: Chroma (colorfulness)
/// - h: Hue in degrees (0-360)
List<num> rgbToOklch(num R, num G, num B) {
  var [l, a, b] = rgbToOklab(R, G, B);

  // Calculate chroma (distance from neutral gray)
  final c = sqrt(a * a + b * b);

  // Calculate hue angle in degrees
  var h = atan2(b, a) * 180 / pi;

  // Normalize hue to 0-360 range
  if (h < 0) {
    h += 360;
  }

  // If chroma is very small, hue is meaningless, set to 0
  if (c < 1e-8) {
    h = 0;
  }

  return [l, c, h];
}

/// Converts OKLCH color directly to linear RGB
///
/// Parameters:
/// - h: Hue (0-1)
/// - c: Chroma (0-1)
/// - l: Lightness (0-1)
///
/// Returns a list of three numbers [R, G, B] in the linear RGB color space (0-1 range)
List<int> oklchToLinearRgb(num h, num c, num l) {
  h *= 360;
  // Convert OKLCH to OKLab
  final a = c * cos(h * pi / 180);
  final b = c * sin(h * pi / 180);

  // Rescale a and b components (to match your rgbToOklab function)
  final a_scaled = a * 0.4;
  final b_scaled = b * 0.4;

  // Convert OKLab to LMS with nonlinear transformation
  final lNonlinear = l + 0.3963377774 * a_scaled + 0.2158037573 * b_scaled;
  final mNonlinear = l - 0.1055613458 * a_scaled - 0.0638541728 * b_scaled;
  final sNonlinear = l - 0.0894841775 * a_scaled - 1.2914855480 * b_scaled;

  // Reverse the nonlinear transformation on LMS
  final l_cubed = lNonlinear * lNonlinear * lNonlinear;
  final m_cubed = mNonlinear * mNonlinear * mNonlinear;
  final s_cubed = sNonlinear * sNonlinear * sNonlinear;

  // Convert LMS to linear RGB
  final linearR =
      4.0767416621 * l_cubed - 3.3077115913 * m_cubed + 0.2309699292 * s_cubed;
  final linearG =
      -1.2684380046 * l_cubed + 2.6097574011 * m_cubed - 0.3413193965 * s_cubed;
  final linearB =
      -0.0041960863 * l_cubed - 0.7034186147 * m_cubed + 1.7076147010 * s_cubed;

  return [
    (linearR * 255).toInt().clamp(0, 255),
    (linearG * 255).toInt().clamp(0, 255),
    (linearB * 255).toInt().clamp(0, 255)
  ];
}

/// Converts OKLCH color to sRGB color
///
/// Parameters:
/// - h: Hue (0-1)
/// - c: Chroma (0-1)
/// - l: Lightness (0-1)
///
/// Returns a list of three integers [r, g, b] in 0-255 range
List<int> oklchToRgb(num h, num c, num l) {
  final linearRgb = oklchToLinearRgb(h, c, l);

  // Apply gamma correction to convert from linear RGB to sRGB
  final r = linearToSrgb(linearRgb[0] / 255);
  final g = linearToSrgb(linearRgb[1] / 255);
  final b = linearToSrgb(linearRgb[2] / 255);

  return [r, g, b];
}

/// Convert linear RGB component to sRGB (0-255 range)
int linearToSrgb(num c) {
  if (c <= 0) return 0;
  if (c >= 1) return 255;

  final srgb = c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055;

  return (srgb * 255).round();
}

ByteMatrix unmap2(
  Byte4Matrix image,
  int compressionLevel,
  List<int> hTolThreshold,
  List<int> hToValue,
) {
  final data = ByteMatrix(height: image.height, width: image.width);

  for (int x = 0; x < image.width; x++) {
    for (int y = 0; y < image.height; y++) {
      final [_, r, g, b] = image[x][y].to4ByteList();
      final [l, c, hShifted] = rgbToOklch(r, g, b);
      final h = ((hShifted - 30 + 360) % 360) / 360;

      final black = 1 << compressionLevel;
      final hInt = (h * 360).toInt();

      data[x][y] = switch ((compressionLevel, h, c, l)) {
        // min compression - all is just black and white
        (0, _, _, <= .5) => black,
        (0, _, _, >= .5) => 0,
        // otherwise - carefully remove black and white
        (_, _, _, <= .05) => black,
        (_, _, _, >= .95) => 0,
        // max compression - handle grays
        (3, _, < .175, <= .5) => 15,
        (3, _, < .175, >= .5) => 7,
        // finally colors
        (_, _, _, _) =>
          hToValue[hInt] + ((hTolThreshold[hInt] / 100 > l) ? black : 0),
      };
    }
  }

  return data;
}
