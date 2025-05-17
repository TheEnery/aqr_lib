import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart';

class Byte4Matrix {
  final List<Uint32List> _columns;
  final int height;
  final int width;

  Byte4Matrix({required this.height, required this.width})
      : _columns = List.generate(width, (_) => Uint32List(height));

  Uint32List operator [](int index) => _columns[index];

  /// Computes the average white color from a 5x5 finder pattern’s outer white pixels.
  int calculateAverageWhite(int centerX, int centerY) {
    //int sumR = 0, sumG = 0, sumB = 0, count = 0;
    int sumR = 0xFF, sumG = 0xFF, sumB = 0xFF;

    // Offsets for outer white ring (not the black frame or the center module)
    final offsets = [
      // Top and bottom rows (excluding corners)
      [-2, -2], [-1, -2], [0, -2], [1, -2], [2, -2], // Top
      [-2, 2], [-1, 2], [0, 2], [1, 2], [2, 2], // Bottom

      // Left and right columns (excluding corners)
      [-2, -1], [-2, 0], [-2, 1], // Left
      [2, -1], [2, 0], [2, 1] // Right
    ];

    for (var offset in offsets) {
      int x = centerX + offset[0];
      int y = centerY + offset[1];

      var [l, r, g, b] = this[x][y].to4ByteList();

      sumR = min(sumR, r);
      sumG = min(sumG, g);
      sumB = min(sumB, b);

      // sumR += r;
      // sumG += g;
      // sumB += b;
      // count++;
    }

    // int avgR = (sumR / count).round();
    // int avgG = (sumG / count).round();
    // int avgB = (sumB / count).round();

    int avgR = sumR;
    int avgG = sumG;
    int avgB = sumB;

    // avgR = (pow(avgR / 255, 2.2).clamp(0, 1) * 255).toInt();
    // avgG = (pow(avgG / 255, 2.2).clamp(0, 1) * 255).toInt();
    // avgB = (pow(avgB / 255, 2.2).clamp(0, 1) * 255).toInt();

    // avgR = avgG = avgB = min(avgR, min(avgG, avgB));

    return (avgR << 8) | (avgG << 16) | (avgB << 24);
  }

  /// Computes the average white color from a 3x3 finder pattern’s inner black pixels.
  int calculateAverageBlack(int centerX, int centerY) {
    int sumR = 0, sumG = 0, sumB = 0;
    //int sumR = 0xFF, sumG = 0xFF, sumB = 0xFF;

    for (int x = -1; x <= 1; x++) {
      for (int y = -1; y <= 1; y++) {
        int xPos = centerX + x;
        int yPos = centerY + y;

        var [l, r, g, b] = this[xPos][yPos].to4ByteList();

        sumR = max(sumR, r);
        sumG = max(sumG, g);
        sumB = max(sumB, b);

        // sumR += r;
        // sumG += g;
        // sumB += b;
        // count++;
      }
    }

    // int avgR = (sumR / count).round();
    // int avgG = (sumG / count).round();
    // int avgB = (sumB / count).round();

    int avgR = sumR;
    int avgG = sumG;
    int avgB = sumB;

    // avgR = (pow(avgR / 255, 1 / 2.2).clamp(0, 1) * 255).toInt();
    // avgG = (pow(avgG / 255, 1 / 2.2).clamp(0, 1) * 255).toInt();
    // avgB = (pow(avgB / 255, 1 / 2.2).clamp(0, 1) * 255).toInt();

    // avgR = avgG = avgB = max(avgR, max(avgG, avgB));

    return (avgR << 8) | (avgG << 16) | (avgB << 24);
  }

  // Corrects the color of the entire QR based on three average white colors from finder patterns.
  // The parameters represent the average white colors from top-left, top-right, and bottom-left finder patterns.
  /// Corrects the color of the entire QR based on three finder pattern locations.
  void balanceColorsFromFinders() {
    int topLeftWhite = calculateAverageWhite(3, 3);
    int topRightWhite = calculateAverageWhite(width - 4, 3);
    int bottomLeftWhite = calculateAverageWhite(3, height - 4);

    int topLeftBlack = calculateAverageBlack(3, 3);
    int topRightBlack = calculateAverageBlack(width - 4, 3);
    int bottomLeftBlack = calculateAverageBlack(3, height - 4);

    int lerp(int a, int b, double i) => (a + (b - a) * i).round();
    double inv_lerp(int a, int b, int x) => (x - a) / (b - a);
    List<int> combine(List<int> rgb1, List<int> rgb2, [double i = 0.5]) => [
          lerp(rgb1[0], rgb2[0], i),
          lerp(rgb1[1], rgb2[1], i),
          lerp(rgb1[2], rgb2[2], i)
        ];

    final tlw = topLeftWhite.to4ByteList().skip(1).toList();
    final trw = topRightWhite.to4ByteList().skip(1).toList();
    final blw = bottomLeftWhite.to4ByteList().skip(1).toList();

    final tlb = topLeftBlack.to4ByteList().skip(1).toList();
    final trb = topRightBlack.to4ByteList().skip(1).toList();
    final blb = bottomLeftBlack.to4ByteList().skip(1).toList();

    final mmw = combine(trw, blw);
    final brw = combine(tlw, mmw, 2);

    final mmb = combine(trb, blb);
    final brb = combine(tlb, mmb, 2);

    // int avgw(int a, int b) => min(a, b); //(a + b) ~/ 2;
    // int avgb(int a, int b) => max(a, b); //(a + b) ~/ 2;

    // final maxR = avgw(avgw(tlw[0], trw[0]), avgw(blw[0], brw[0]));
    // final maxG = avgw(avgw(tlw[1], trw[1]), avgw(blw[1], brw[1]));
    // final maxB = avgw(avgw(tlw[2], trw[2]), avgw(blw[2], brw[2]));

    // final minR = avgb(avgb(tlb[0], trb[0]), avgb(blb[0], brb[0]));
    // final minG = avgb(avgb(tlb[1], trb[1]), avgb(blb[1], brb[1]));
    // final minB = avgb(avgb(tlb[2], trb[2]), avgb(blb[2], brb[2]));

    // print(tlw);
    // print(trw);
    // print(blw);
    // print(brw);

    for (int x = 0; x < width; x++) {
      final column = this[x];
      for (int y = 0; y < height; y++) {
        final tw = combine(tlw, trw, x / width);
        final bw = combine(blw, brw, x / width);
        final cw = combine(tw, bw, y / height);

        final tb = combine(tlb, trb, x / width);
        final bb = combine(blb, brb, x / width);
        final cb = combine(tb, bb, y / height);

        int pixel = column[y];
        var [L, R, G, B] = pixel.to4ByteList();
        R = (inv_lerp(cb[0], cw[0], R) * 255).round().clamp(0, 255);
        G = (inv_lerp(cb[1], cw[1], G) * 255).round().clamp(0, 255);
        B = (inv_lerp(cb[2], cw[2], B) * 255).round().clamp(0, 255);
        // var [h, s, l] = rgbToHsl(R, G, B);
        // h = (((h * 360).toInt() + 30) % 360) ~/ 60 / 6;
        // [R, G, B] = hslToRgb(h, s, l);
        column[y] = [L, R, G, B].to4ByteUint();
      }
    }
  }

  void applyGamma(double gamma) {
    for (int x = 0; x < width; x++) {
      final column = this[x];
      for (int y = 0; y < height; y++) {
        var [l, r, g, b] = column[y].to4ByteList();
        r = (pow(r / 255, gamma).clamp(0, 1) * 255).toInt();
        g = (pow(g / 255, gamma).clamp(0, 1) * 255).toInt();
        b = (pow(b / 255, gamma).clamp(0, 1) * 255).toInt();
        column[y] = [l, r, g, b].to4ByteUint();
      }
    }
  }

  Image toImage() {
    final image = Image(width: width, height: height);
    for (int x = 0; x < width; x++) {
      final column = this[x];
      for (int y = 0; y < height; y++) {
        final [l, r, g, b] = column[y].to4ByteList();
        image.setPixelRgb(x, y, r, g, b);
      }
    }
    return image;
  }
}

extension IntToList on int {
  List<int> to4ByteList() => [
        (this >> 0) & 0xFF,
        (this >> 8) & 0xFF,
        (this >> 16) & 0xFF,
        (this >> 24) & 0xFF,
      ];

  int get l => (this >> 0) & 0xFF;
  int get r => (this >> 8) & 0xFF;
  int get g => (this >> 16) & 0xFF;
  int get b => (this >> 24) & 0xFF;
}

extension ListToInt on List<int> {
  int to4ByteUint() =>
      (this[0] << 0) | (this[1] << 8) | (this[2] << 16) | (this[3] << 24);
}
