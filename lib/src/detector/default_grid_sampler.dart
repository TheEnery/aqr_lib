/*
 * Copyright 2007 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import '../core/byte4_matrix.dart';
import '../exceptions/not_found_exception.dart';

import 'perspective_transform.dart';

/// @author Sean Owen
class DefaultGridSampler {
  Byte4Matrix sampleGrid(
    Byte4Matrix image,
    int dimensionX,
    int dimensionY,
    PerspectiveTransform transform,
  ) {
    if (dimensionX <= 0 || dimensionY <= 0) {
      throw NotFoundException.instance;
    }
    final bits = Byte4Matrix(width: dimensionX, height: dimensionY);
    final points = List.filled(2 * dimensionX, 0.0);
    for (int y = 0; y < dimensionY; y++) {
      final max = points.length;
      final iValue = y + 0.5;
      for (int x = 0; x < max; x += 2) {
        points[x] = (x / 2) + 0.5;
        points[x + 1] = iValue;
      }
      transform.transformPoints(points);
      // Quick check to see if points transformed to something inside the image;
      // sufficient to check the endpoints
      checkAndNudgePoints(image, points);
      try {
        for (int x = 0; x < max; x += 2) {
          //if (image[points[x].toInt()][points[x + 1].toInt()] & 1 == 1) {
          // Black(-ish) pixel
          ///bits[x ~/ 2][y] = image[points[x].toInt()][points[x + 1].toInt()];
          //}
          int ix = points[x].toInt();
          int iy = points[x + 1].toInt();

          final c = image[ix][iy].to4ByteList();
          final t = image[ix][iy - 1].to4ByteList();
          final b = image[ix][iy + 1].to4ByteList();
          final l = image[ix - 1][iy].to4ByteList();
          final r = image[ix + 1][iy].to4ByteList();
          final tl = image[ix - 1][iy - 1].to4ByteList();
          final bl = image[ix - 1][iy + 1].to4ByteList();
          final tr = image[ix + 1][iy - 1].to4ByteList();
          final br = image[ix + 1][iy + 1].to4ByteList();

          final n = [
            ((c[0] +
                        t[0] +
                        b[0] +
                        l[0] +
                        r[0] +
                        tl[0] +
                        bl[0] +
                        tr[0] +
                        br[0]) /
                    9)
                .round(),
            ((c[1] +
                        t[1] +
                        b[1] +
                        l[1] +
                        r[1] +
                        tl[1] +
                        bl[1] +
                        tr[1] +
                        br[1]) /
                    9)
                .round(),
            ((c[2] +
                        t[2] +
                        b[2] +
                        l[2] +
                        r[2] +
                        tl[2] +
                        bl[2] +
                        tr[2] +
                        br[2]) /
                    9)
                .round(),
            ((c[3] +
                        t[3] +
                        b[3] +
                        l[3] +
                        r[3] +
                        tl[3] +
                        bl[3] +
                        tr[3] +
                        br[3]) /
                    9)
                .round(),
          ];

          bits[x ~/ 2][y] = n.to4ByteUint();
        }
      } on RangeError catch (_) {
        // on ArrayIndexOutOfBoundsException

        // This feels wrong, but, sometimes if the finder patterns are misidentified, the resulting
        // transform gets "twisted" such that it maps a straight line of points to a set of points
        // whose endpoints are in bounds, but others are not. There is probably some mathematical
        // way to detect this about the transformation that I don't know yet.
        // This results in an ugly runtime exception despite our clever checks above -- can't have
        // that. We could check each point's coordinates but that feels duplicative. We settle for
        // catching and wrapping ArrayIndexOutOfBoundsException.
        throw NotFoundException.instance;
      }
    }
    return bits;
  }

  Byte4Matrix sampleGridPart(
    Byte4Matrix image,
    int startX,
    int startY,
    int dimensionX,
    int dimensionY,
    PerspectiveTransform transform,
  ) {
    if (dimensionX <= 0 || dimensionY <= 0) {
      throw NotFoundException.instance;
    }
    final bits = Byte4Matrix(width: dimensionX, height: dimensionY);
    final points = List.filled(2 * dimensionX, 0.0);
    for (int y = 0; y < dimensionY; y++) {
      final max = points.length;
      final iValue = y + 0.5;
      for (int x = 0; x < max; x += 2) {
        points[x] = (x / 2) + 0.5 + startX;
        points[x + 1] = iValue + startY;
      }

      transform.transformPoints(points);
      // Quick check to see if points transformed to something inside the image;
      // sufficient to check the endpoints
      checkAndNudgePoints(image, points);
      try {
        for (int x = 0; x < max; x += 2) {
          //if (image.get(points[x].toInt(), points[x + 1].toInt())) {
          // Black(-ish) pixel
          bits[x ~/ 2][y] = image[points[x].toInt()][points[x + 1].toInt()];
          //}
        }
      } on RangeError catch (_) {
        // on ArrayIndexOutOfBoundsException

        // This feels wrong, but, sometimes if the finder patterns are misidentified, the resulting
        // transform gets "twisted" such that it maps a straight line of points to a set of points
        // whose endpoints are in bounds, but others are not. There is probably some mathematical
        // way to detect this about the transformation that I don't know yet.
        // This results in an ugly runtime exception despite our clever checks above -- can't have
        // that. We could check each point's coordinates but that feels duplicative. We settle for
        // catching and wrapping ArrayIndexOutOfBoundsException.
        throw NotFoundException.instance;
      }
    }
    return bits;
  }

  /// <p>Checks a set of points that have been transformed to sample points on an image against
  /// the image's dimensions to see if the point are even within the image.</p>
  ///
  /// <p>This method will actually "nudge" the endpoints back onto the image if they are found to be
  /// barely (less than 1 pixel) off the image. This accounts for imperfect detection of finder
  /// patterns in an image where the QR Code runs all the way to the image border.</p>
  ///
  /// <p>For efficiency, the method will check points from either end of the line until one is found
  /// to be within the image. Because the set of points are assumed to be linear, this is valid.</p>
  ///
  /// @param image image into which the points should map
  /// @param points actual points in x1,y1,...,xn,yn form
  /// @throws NotFoundException if an endpoint is lies outside the image boundaries
  //@protected
  static void checkAndNudgePoints(Byte4Matrix image, List<double> points) {
    final width = image.width;
    final height = image.height;
    // Check and nudge points from start until we see some that are OK:
    bool nudged = true;
    final maxOffset = points.length - 1; // points.length must be even
    for (int offset = 0; offset < maxOffset && nudged; offset += 2) {
      final x = points[offset].toInt();
      final y = points[offset + 1].toInt();
      if (x < -1 || x > width || y < -1 || y > height) {
        throw NotFoundException.instance;
      }
      nudged = false;
      if (x == -1) {
        points[offset] = 0.0;
        nudged = true;
      } else if (x == width) {
        points[offset] = width - 1;
        nudged = true;
      }
      if (y == -1) {
        points[offset + 1] = 0.0;
        nudged = true;
      } else if (y == height) {
        points[offset + 1] = height - 1;
        nudged = true;
      }
    }
    // Check and nudge points from end:
    nudged = true;
    for (int offset = points.length - 2; offset >= 0 && nudged; offset -= 2) {
      final x = points[offset].toInt();
      final y = points[offset + 1].toInt();
      if (x < -1 || x > width || y < -1 || y > height) {
        throw NotFoundException.instance;
      }
      nudged = false;
      if (x == -1) {
        points[offset] = 0.0;
        nudged = true;
      } else if (x == width) {
        points[offset] = width - 1;
        nudged = true;
      }
      if (y == -1) {
        points[offset + 1] = 0.0;
        nudged = true;
      } else if (y == height) {
        points[offset + 1] = height - 1;
        nudged = true;
      }
    }
  }
}
