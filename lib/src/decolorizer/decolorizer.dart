import 'dart:math';

import 'package:image/image.dart';

import '../core/byte4_matrix.dart';
import '../core/byte_matrix.dart';
import '../core/compression.dart';
import '../decolorizer/unmap.dart';

///irrelevant
class Decolorizer {
  late Compression compression;
  late ByteMatrix matrix;

  void decolorize(Byte4Matrix image) {
    image.balanceColorsFromFinders();
    image.applyGamma(2.4);
    final palette = extractDistinctColorsZigzag(image, distanceThreshold: 140);
    print(palette.length);
    applyWhiteBalance(palette);

    final level = (log(palette.length) / log(2)).toInt() - 1;

    compression = Compression.withCustomPalette(
        level: level,
        palette: palette
            .map((c) => ColorRgb8(c[0], c[1], c[2]))
            .toList()
            .cast<Color>());

    matrix = unmap(image, compression.palette);
  }

  void applyWhiteBalance(List<List<int>> palette) {
    List<int> mostW = [0, 0, 0];

    for (final color in palette) {
      if (mostW[0] < color[0]) mostW[0] = color[0];
      if (mostW[1] < color[1]) mostW[1] = color[1];
      if (mostW[2] < color[2]) mostW[2] = color[2];
    }

    print(mostW);

    for (final color in palette) {
      color[0] = ((color[0] / mostW[0]).clamp(0, 1) * 255).toInt();
      color[1] = ((color[1] / mostW[1]).clamp(0, 1) * 255).toInt();
      color[2] = ((color[2] / mostW[2]).clamp(0, 1) * 255).toInt();
    }
  }

  List<List<int>> extractDistinctColorsZigzag(
    Byte4Matrix image, {
    int minOccurrence = 5,
    int distanceThreshold = 150,
  }) {
    List<_ColorEntry> distinctColors = [];

    /// Computes a simplified distance between two colors using sum of absolute differences.
    int simplifiedDistance(
        double r1, double g1, double b1, int r2, int g2, int b2) {
      return ((r1 - r2).abs() + (g1 - g2).abs() + (b1 - b2).abs()).round();
    }

    // Local helper: process the pixel at (x, y)
    void processPixel(int x, int y) {
      final [_, r, g, b] = image[x][y].to4ByteList();

      // Find the most similar distinct color.
      int bestDistance = 1 << 30; // large number
      _ColorEntry? bestCandidate;

      for (_ColorEntry candidate in distinctColors) {
        int dist =
            simplifiedDistance(candidate.r, candidate.g, candidate.b, r, g, b);
        if (dist < bestDistance) {
          bestDistance = dist;
          bestCandidate = candidate;
        }
      }

      // If a candidate exists and is similar enough, merge; otherwise, add as new.
      if (bestCandidate != null && bestDistance < distanceThreshold) {
        bestCandidate.merge(r, g, b);
      } else {
        distinctColors
            .add(_ColorEntry(r.toDouble(), g.toDouble(), b.toDouble(), 1));
      }
    }

    // Zigzag traversal: even rows left-to-right, odd rows right-to-left.
    for (int y = image.height - 1; y >= 0; y--) {
      if (y % 2 == 0) {
        // left-to-right
        for (int x = 0; x < image.width; x++) {
          processPixel(x, y);
        }
      } else {
        // right-to-left
        for (int x = image.width - 1; x >= 0; x--) {
          processPixel(x, y);
        }
      }
    }

    var filtered =
        distinctColors.where((entry) => entry.count >= minOccurrence).toList();

    final level = (log(filtered.length) / log(2)).toInt() - 1;
    final length = 2 << level;

    if (length != filtered.length) {
      filtered.sort((c1, c2) => c2.count.compareTo(c1.count));
      filtered = filtered.take(length).toList();
    }

    // Now filter out colors with count less than minOccurrence.
    List<List<int>> result = filtered
        .map((entry) => [entry.r.round(), entry.g.round(), entry.b.round()])
        .toList();

    return result;
  }
}

/// Container for a distinct color entry with its weighted average and occurrence count.
class _ColorEntry {
  double r, g, b;
  int count;

  _ColorEntry(this.r, this.g, this.b, this.count);

  /// Updates this entry by merging in a new color (cr, cg, cb) with weight 1.
  void merge(int cr, int cg, int cb) {
    r = (r * count + cr) / (count + 1);
    g = (g * count + cg) / (count + 1);
    b = (b * count + cb) / (count + 1);
    count++;
  }
}
