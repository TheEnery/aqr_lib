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

import 'dart:math' show min, max;

import '../core/byte4_matrix.dart';
import '../core/version.dart';
import '../exceptions/formats_exception.dart';
import '../exceptions/not_found_exception.dart';

import 'alignment_pattern.dart';
import 'alignment_pattern_finder.dart';
import 'default_grid_sampler.dart';
import 'detector_result.dart';
import 'finder_pattern_finder.dart';
import 'perspective_transform.dart';
import 'result_point.dart';

/// Encapsulates logic that can detect a QR Code in an image, even if the QR Code
/// is rotated or skewed, or partially obscured.
///
/// @author Sean Owen
class Detector {
  final Byte4Matrix image;

  Detector(this.image);

  /// <p>Detects a QR Code in an image.</p>
  ///
  /// @param hints optional hints to detector
  /// @return [DetectorResult] encapsulating results of detecting a QR Code
  /// @throws NotFoundException if QR Code cannot be found
  /// @throws FormatException if a QR Code cannot be decoded
  DetectorResult detect() {
    final finder = FinderPatternFinder(image);
    final info = finder.find();

    return processFinderPatternInfo(info);
  }

  DetectorResult processFinderPatternInfo(FinderPatternInfo info) {
    final topLeft = info.topLeft;
    final topRight = info.topRight;
    final bottomLeft = info.bottomLeft;

    final moduleSize = calculateModuleSize(topLeft, topRight, bottomLeft);
    if (moduleSize < 1.0) {
      throw NotFoundException.instance;
    }
    final dimension =
        _computeDimension(topLeft, topRight, bottomLeft, moduleSize);
    final provisionalVersionNumber = Version.tryDeduceNumber(dimension);
    if (provisionalVersionNumber == null) throw FormatsException.instance;
    final modulesBetweenFPCenters = dimension - 7;

    AlignmentPattern? alignmentPattern;
    // Anything above version 1 has an alignment pattern
    if (provisionalVersionNumber > 1) {
      // Guess where a "bottom right" finder pattern would have been
      final bottomRightX = topRight.x - topLeft.x + bottomLeft.x;
      final bottomRightY = topRight.y - topLeft.y + bottomLeft.y;

      // Estimate that alignment pattern is closer by 3 modules
      // from "bottom right" to known top left location
      final correctionToTopLeft = 1.0 - 3.0 / modulesBetweenFPCenters;
      final estAlignmentX =
          (topLeft.x + correctionToTopLeft * (bottomRightX - topLeft.x))
              .toInt();
      final estAlignmentY =
          (topLeft.y + correctionToTopLeft * (bottomRightY - topLeft.y))
              .toInt();

      // Kind of arbitrary -- expand search radius before giving up
      for (int i = 4; i <= 16; i <<= 1) {
        try {
          alignmentPattern = findAlignmentInRegion(
            moduleSize,
            estAlignmentX,
            estAlignmentY,
            i.toDouble(),
          );
          break;
        } on NotFoundException catch (_) {
          // try next round
        }
      }
      // If we didn't find alignment pattern... well try anyway without it
    }

    final transform = _createTransform(
      topLeft,
      topRight,
      bottomLeft,
      alignmentPattern,
      dimension,
    );

    final bits = _sampleGrid(image, transform, dimension);

    late List<ResultPoint> points;
    if (alignmentPattern == null) {
      points = [bottomLeft, topLeft, topRight];
    } else {
      points = [bottomLeft, topLeft, topRight, alignmentPattern];
    }
    return DetectorResult(bits, points);
  }

  static PerspectiveTransform _createTransform(
    ResultPoint topLeft,
    ResultPoint topRight,
    ResultPoint bottomLeft,
    ResultPoint? alignmentPattern,
    int dimension,
  ) {
    final dimMinusThree = dimension - 3.5;
    double bottomRightX;
    double bottomRightY;
    double sourceBottomRightX;
    double sourceBottomRightY;
    if (alignmentPattern != null) {
      bottomRightX = alignmentPattern.x;
      bottomRightY = alignmentPattern.y;
      sourceBottomRightX = dimMinusThree - 3.0;
      sourceBottomRightY = sourceBottomRightX;
    } else {
      // Don't have an alignment pattern, just make up the bottom-right point
      bottomRightX = (topRight.x - topLeft.x) + bottomLeft.x;
      bottomRightY = (topRight.y - topLeft.y) + bottomLeft.y;
      sourceBottomRightX = dimMinusThree;
      sourceBottomRightY = dimMinusThree;
    }

    return PerspectiveTransform.quadrilateralToQuadrilateral(
      3.5,
      3.5,
      dimMinusThree,
      3.5,
      sourceBottomRightX,
      sourceBottomRightY,
      3.5,
      dimMinusThree,
      topLeft.x,
      topLeft.y,
      topRight.x,
      topRight.y,
      bottomRightX,
      bottomRightY,
      bottomLeft.x,
      bottomLeft.y,
    );
  }

  static Byte4Matrix _sampleGrid(
    Byte4Matrix image,
    PerspectiveTransform transform,
    int dimension,
  ) {
    final sampler = DefaultGridSampler();
    return sampler.sampleGrid(image, dimension, dimension, transform);
  }

  static int round(double d) {
    if (d.isNaN) return 0;
    if (d.isInfinite) {
      if (d.sign == 1) {
        return 2147483647;
      } else {
        return -2147483648;
      }
    }
    return (d + (d < 0.0 ? -0.5 : 0.5)).toInt();
  }

  /// <p>Computes the dimension (number of modules on a size) of the QR Code based on the position
  /// of the finder patterns and estimated module size.</p>
  int _computeDimension(
    ResultPoint topLeft,
    ResultPoint topRight,
    ResultPoint bottomLeft,
    double moduleSize,
  ) {
    final tltrCentersDimension =
        round(ResultPoint.distance(topLeft, topRight) / moduleSize);
    final tlblCentersDimension =
        round(ResultPoint.distance(topLeft, bottomLeft) / moduleSize);
    int dimension = ((tltrCentersDimension + tlblCentersDimension) ~/ 2) + 7;

    //////////
    print('');
    print('calc: $dimension');

    try {
      if (dimension >= (6 * 4 + 17 + 2)) {
        int? version;
        final transform =
            _createTransform(topLeft, topRight, bottomLeft, null, dimension);
        final versionBits1 = _readTopRightVersionBits(transform, dimension);
        version = Version.tryDecodeNumber(versionBits1);

        print('my1: $version');

        if (version == null) {
          final versionBits2 = _readBottomLeftVersionBits(transform, dimension);
          version = Version.tryDecodeNumber(versionBits2);

          print('my2: $version');
        }

        if (version != null) dimension = 4 * version + 17;
      }
    } catch (e) {
      print(e);
    }
    print('');
    ////////////

    switch (dimension & 0x03) {
      // mod 4
      case 0:
        dimension++;
        break;
      // 1? do nothing
      case 2:
        dimension--;
        break;
      case 3:
        throw NotFoundException.instance;
    }
    return dimension;
  }

  int _readTopRightVersionBits(PerspectiveTransform transform, int dimension) {
    int startX = dimension - 11;
    int startY = 0;

    final versionMatrix = DefaultGridSampler()
        .sampleGridPart(image, startX, startY, 3, 6, transform);

    //print(versionMatrix.toString());

    int versionBits = 0;
    for (int j = 5; j >= 0; j--) {
      for (int i = 2; i >= 0; i--) {
        versionBits = (versionBits << 1) | (versionMatrix[i][j] & 1);
      }
    }

    return versionBits;
  }

  int _readBottomLeftVersionBits(
      PerspectiveTransform transform, int dimension) {
    int startX = 0;
    int startY = dimension - 11;

    final versionMatrix = DefaultGridSampler()
        .sampleGridPart(image, startX, startY, 6, 3, transform);

    //print(versionMatrix.toString());

    int versionBits = 0;
    for (int x = 5; x >= 0; x--) {
      for (int y = 2; y >= 0; y--) {
        versionBits = (versionBits << 1) | (versionMatrix[x][y] & 1);
      }
    }

    return versionBits;
  }

  /// <p>Computes an average estimated module size based on estimated derived from the positions
  /// of the three finder patterns.</p>
  ///
  /// @param topLeft detected top-left finder pattern center
  /// @param topRight detected top-right finder pattern center
  /// @param bottomLeft detected bottom-left finder pattern center
  /// @return estimated module size
  //@protected
  double calculateModuleSize(
    ResultPoint topLeft,
    ResultPoint topRight,
    ResultPoint bottomLeft,
  ) {
    // Take the average
    return (_calculateModuleSizeOneWay(topLeft, topRight) +
            _calculateModuleSizeOneWay(topLeft, bottomLeft)) /
        2.0;
  }

  /// <p>Estimates module size based on two finder patterns -- it uses
  /// {link #sizeOfBlackWhiteBlackRunBothWays(int, int, int, int)} to figure the
  /// width of each, measuring along the axis between their centers.</p>
  double _calculateModuleSizeOneWay(
    ResultPoint pattern,
    ResultPoint otherPattern,
  ) {
    final moduleSizeEst1 = _sizeOfBlackWhiteBlackRunBothWays(
      pattern.x.toInt(),
      pattern.y.toInt(),
      otherPattern.x.toInt(),
      otherPattern.y.toInt(),
    );
    final moduleSizeEst2 = _sizeOfBlackWhiteBlackRunBothWays(
      otherPattern.x.toInt(),
      otherPattern.y.toInt(),
      pattern.x.toInt(),
      pattern.y.toInt(),
    );
    if ((moduleSizeEst1).isNaN) {
      return moduleSizeEst2 / 7.0;
    }
    if ((moduleSizeEst2).isNaN) {
      return moduleSizeEst1 / 7.0;
    }
    // Average them, and divide by 7 since we've counted the width of 3 black modules,
    // and 1 white and 1 black module on either side. Ergo, divide sum by 14.
    return (moduleSizeEst1 + moduleSizeEst2) / 14.0;
  }

  /// See {@link #sizeOfBlackWhiteBlackRun(int, int, int, int)}; computes the total width of
  /// a finder pattern by looking for a black-white-black run from the center in the direction
  /// of another point (another finder pattern center), and in the opposite direction too.
  double _sizeOfBlackWhiteBlackRunBothWays(
    int fromX,
    int fromY,
    int toX,
    int toY,
  ) {
    double result = _sizeOfBlackWhiteBlackRun(fromX, fromY, toX, toY);

    // Now count other way -- don't run off image though of course
    double scale = 1.0;
    int otherToX = fromX - (toX - fromX);
    if (otherToX < 0) {
      scale = fromX / (fromX - otherToX);
      otherToX = 0;
    } else if (otherToX >= image.width) {
      scale = (image.width - 1 - fromX) / (otherToX - fromX);
      otherToX = image.width - 1;
    }
    int otherToY = (fromY - (toY - fromY) * scale).toInt();

    scale = 1.0;
    if (otherToY < 0) {
      scale = fromY / (fromY - otherToY);
      otherToY = 0;
    } else if (otherToY >= image.height) {
      scale = (image.height - 1 - fromY) / (otherToY - fromY);
      otherToY = image.height - 1;
    }
    otherToX = (fromX + (otherToX - fromX) * scale).toInt();

    result += _sizeOfBlackWhiteBlackRun(fromX, fromY, otherToX, otherToY);

    // Middle pixel is double-counted this way; subtract 1
    return result - 1.0;
  }

  /// <p>This method traces a line from a point in the image, in the direction towards another point.
  /// It begins in a black region, and keeps going until it finds white, then black, then white again.
  /// It reports the distance from the start to this point.</p>
  ///
  /// <p>This is used when figuring out how wide a finder pattern is, when the finder pattern
  /// may be skewed or rotated.</p>
  double _sizeOfBlackWhiteBlackRun(int fromX, int fromY, int toX, int toY) {
    // Mild variant of Bresenham's algorithm;
    // see http://en.wikipedia.org/wiki/Bresenham's_line_algorithm
    final steep = (toY - fromY).abs() > (toX - fromX).abs();
    if (steep) {
      int temp = fromX;
      fromX = fromY;
      fromY = temp;
      temp = toX;
      toX = toY;
      toY = temp;
    }

    final dx = (toX - fromX).abs();
    final dy = (toY - fromY).abs();
    int error = -dx ~/ 2;
    final xstep = fromX < toX ? 1 : -1;
    final ystep = fromY < toY ? 1 : -1;

    // In black pixels, looking for white, first or second time.
    int state = 0;
    // Loop up until x == toX, but not beyond
    final xLimit = toX + xstep;
    for (int x = fromX, y = fromY; x != xLimit; x += xstep) {
      final realX = steep ? y : x;
      final realY = steep ? x : y;

      // Does current pixel mean we have moved white to black or vice versa?
      // Scanning black in state 0,2 and white in state 1, so if we find the wrong
      // color, advance to next state or end if we are in state 2 already
      if ((state == 1) == (image[realX][realY].to4ByteList()[0] == 1)) {
        if (state == 2) {
          return ResultPoint.distance2(
            x.toDouble(),
            y.toDouble(),
            fromX.toDouble(),
            fromY.toDouble(),
          );
        }
        state++;
      }

      error += dy;
      if (error > 0) {
        if (y == toY) {
          break;
        }
        y += ystep;
        error -= dx;
      }
    }
    // Found black-white-black; give the benefit of the doubt that the next pixel outside the image
    // is "white" so this last point at (toX+xStep,toY) is the right ending. This is really a
    // small approximation; (toX+xStep,toY+yStep) might be really correct. Ignore this.
    if (state == 2) {
      return ResultPoint.distance2(
        (toX + xstep).toDouble(),
        toY.toDouble(),
        fromX.toDouble(),
        fromY.toDouble(),
      );
    }
    // else we didn't find even black-white-black; no estimate is really possible
    return double.nan;
  }

  /// <p>Attempts to locate an alignment pattern in a limited region of the image, which is
  /// guessed to contain it. This method uses [AlignmentPattern].</p>
  ///
  /// @param overallEstModuleSize estimated module size so far
  /// @param estAlignmentX x coordinate of center of area probably containing alignment pattern
  /// @param estAlignmentY y coordinate of above
  /// @param allowanceFactor number of pixels in all directions to search from the center
  /// @return [AlignmentPattern] if found, or null otherwise
  /// @throws NotFoundException if an unexpected error occurs during detection
  //@protected
  AlignmentPattern findAlignmentInRegion(
    double overallEstModuleSize,
    int estAlignmentX,
    int estAlignmentY,
    double allowanceFactor,
  ) {
    // Look for an alignment pattern (3 modules in size) around where it
    // should be
    final allowance = (allowanceFactor * overallEstModuleSize).toInt();
    final alignmentAreaLeftX = max(0, estAlignmentX - allowance);
    final alignmentAreaRightX = min(image.width - 1, estAlignmentX + allowance);
    if (alignmentAreaRightX - alignmentAreaLeftX < overallEstModuleSize * 3) {
      throw NotFoundException.instance;
    }

    final alignmentAreaTopY = max(0, estAlignmentY - allowance);
    final alignmentAreaBottomY =
        min(image.height - 1, estAlignmentY + allowance);
    if (alignmentAreaBottomY - alignmentAreaTopY < overallEstModuleSize * 3) {
      throw NotFoundException.instance;
    }

    final alignmentFinder = AlignmentPatternFinder(
      image,
      alignmentAreaLeftX,
      alignmentAreaTopY,
      alignmentAreaRightX - alignmentAreaLeftX,
      alignmentAreaBottomY - alignmentAreaTopY,
      overallEstModuleSize,
    );
    return alignmentFinder.find();
  }
}
