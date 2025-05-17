/*
 * Copyright 2025 TheEnery
 * Copyright 2008 ZXing authors
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

import '../exceptions/writer_exception.dart';

import 'bit_reader.dart';
import 'bit_writer.dart';
import 'byte_matrix.dart';
import 'format_information.dart';
import 'mask.dart';
import 'version.dart';

/// @author satorux@google.com (Satoru Takabayashi) - creator
/// @author dswitkin@google.com (Daniel Switkin) - ported from C++
class MatrixBuilder {
  static const int noModule = 0xFF;

  final ByteMatrix matrix;
  final Version version;

  MatrixBuilder({required this.version})
      : matrix = ByteMatrix.square(dimension: version.dimension);

  void buildMatrix({required BitReader data, required Mask mask}) {
    resetMatrix();
    embedBasicPatterns();
    embedFormatInformation(mask);
    maybeEmbedVersionInfo();
    embedDataBits(data, mask);
  }

  void buildDummyMatrix() {
    final dimension = version.dimension;
    final alignmentPatternCenters = version.alignmentPatternCenters;

    void setRegion(int x1, int y1, int width, int height) {
      for (int y = y1; y < y1 + height; y++) {
        for (int x = x1; x < x1 + width; x++) {
          matrix[x][y] = noModule;
        }
      }
    }

    // Top left finder pattern + separator + format
    setRegion(0, 0, 9, 9);
    // Top right finder pattern + separator + format
    setRegion(dimension - 8, 0, 8, 9);
    // Bottom left finder pattern + separator + format
    setRegion(0, dimension - 8, 9, 8);

    // Alignment patterns
    final max = alignmentPatternCenters.length;
    for (int x = 0; x < max; x++) {
      final i = alignmentPatternCenters[x] - 2;
      for (int y = 0; y < max; y++) {
        if ((x != 0 || (y != 0 && y != max - 1)) && (x != max - 1 || y != 0)) {
          setRegion(alignmentPatternCenters[y] - 2, i, 5, 5);
        }
        // else no o alignment patterns near the three finder patterns
      }
    }

    // Vertical timing pattern
    setRegion(6, 9, 1, dimension - 17);
    // Horizontal timing pattern
    setRegion(9, 6, dimension - 17, 1);

    if (version.number >= 7) {
      // Version info, top right
      setRegion(dimension - 11, 0, 3, 6);
      // Version info, bottom left
      setRegion(0, dimension - 11, 6, 3);
    }
  }

  void resetMatrix() {
    matrix.fill(noModule);
  }

  // Embed basic patterns. On success, modify the matrix and return true.
  // The basic patterns are:
  // - Position detection patterns
  // - Timing patterns
  // - Dark dot at the left bottom corner
  // - Position adjustment patterns, if need be
  void embedBasicPatterns() {
    // Let's get started with embedding big squares at corners.
    _embedPositionDetectionPatternsAndSeparators();
    // Then, embed the dark dot at the left bottom corner.
    _embedDarkDotAtLeftBottomCorner();

    // Position adjustment patterns appear if version >= 2.
    _maybeEmbedPositionAdjustmentPatterns();
    // Timing patterns should be embedded after position adj. patterns.
    _embedTimingPatterns();
  }

  // Embed type information. On success, modify the matrix.
  void embedFormatInformation(Mask mask) {
    final formatInformation =
        FormatInformation(errorCorrection: version.errorCorrection, mask: mask);
    final typeInfoBitsWriter = BitWriter()
      ..addInt(formatInformation.encodedBits, FormatInformation.bitCount);
    final typeInfoBits = typeInfoBitsWriter.reader;

    for (int i = 0; i < typeInfoBits.length; ++i) {
      // Place bits in LSB to MSB order.  LSB (least significant bit) is the last value in
      // "typeInfoBits".
      final bit = typeInfoBits[typeInfoBits.length - 1 - i];

      // Type info bits at the left top corner. See 8.9 of JISX0510:2004 (p.46).
      final coordinates = _typeInfoCoordinates[i];
      final x1 = coordinates[0];
      final y1 = coordinates[1];
      matrix[x1][y1] = bit ? version.compression.darkestValue : 0;

      int x2;
      int y2;
      if (i < 8) {
        // Right top corner.
        x2 = matrix.width - i - 1;
        y2 = 8;
      } else {
        // Left bottom corner.
        x2 = 8;
        y2 = matrix.height - 7 + (i - 8);
      }
      matrix[x2][y2] = bit ? version.compression.darkestValue : 0;
    }
  }

  // Embed version information if need be. On success, modify the matrix and return true.
  // See 8.10 of JISX0510:2004 (p.47) for how to embed version information.
  void maybeEmbedVersionInfo() {
    if (version.number < 7) {
      // Version info is necessary if version >= 7.
      return; // Don't need version info.
    }
    final versionInfoBitsWriter = BitWriter()
      ..addInt(version.encodedBits, Version.bitCount);
    final versionInfoBits = versionInfoBitsWriter.reader;

    int bitIndex = 6 * 3 - 1; // It will decrease from 17 to 0.
    for (int i = 0; i < 6; ++i) {
      for (int j = 0; j < 3; ++j) {
        // Place bits in LSB (least significant bit) to MSB order.
        final bit = versionInfoBits[bitIndex];
        bitIndex--;
        // Left bottom corner.
        matrix[i][matrix.height - 11 + j] =
            bit ? version.compression.darkestValue : 0;
        // Right bottom corner.
        matrix[matrix.height - 11 + j][i] =
            bit ? version.compression.darkestValue : 0;
      }
    }
  }

  // Embed "dataBits" using "getMaskPattern". On success, modify the matrix and return true.
  // For debugging purposes, it skips masking process if "getMaskPattern" is -1.
  // See 8.7 of JISX0510:2004 (p.38) for how to embed data bits.
  void embedDataBits(BitReader data, Mask mask) {
    final isMasked = mask.isMasked;
    final includeBits = version.compression.bitMask;
    //int bitIndex = 0;
    int direction = -1;
    // Start from the right bottom cell.
    int x = matrix.width - 1;
    int y = matrix.height - 1;
    while (x > 0) {
      // Skip the vertical timing pattern.
      if (x == 6) {
        x -= 1;
      }
      while (y >= 0 && y < matrix.height) {
        for (int i = 0; i < 2; ++i) {
          final xx = x - i;
          // Skip the cell if it's not empty.
          if (!_isEmpty(matrix[xx][y])) {
            continue;
          }
          int bits = 0;
          if (data.available > 0) {
            bits = data.getInt(version.compression.bitsPerModule);
          } else {
            // Padding bit. If there is no bit left, we'll fill the left cells with 0, as described
            // in 8.4.9 of JISX0510:2004 (p. 24).
            bits = 0;
          }

          matrix[xx][y] = isMasked(xx, y) ? ~bits & includeBits : bits;
        }
        y += direction;
      }
      direction = -direction; // Reverse the direction.
      y += direction;
      x -= 2; // Move to the left.
    }
    // All bits should be consumed.
    if (data.available > 0) {
      //if (bitIndex != dataBits.length) {
      throw WriterException(
        'Not all bits consumed: ${data.available}' '/${data.length}',
      );
    }
  }

  // Check if "value" is empty.
  bool _isEmpty(int value) {
    return value == noModule;
  }

  void _embedTimingPatterns() {
    // -8 is for skipping position detection patterns (size 7), and two horizontal/vertical
    // separation patterns (size 1). Thus, 8 = 7 + 1.
    for (int i = 8; i < matrix.width - 8; ++i) {
      final bit = ((i + 1) % 2 == 1) ? version.compression.darkestValue : 0;
      // Horizontal line.
      if (_isEmpty(matrix[i][6])) {
        matrix[i][6] = bit;
      }
      // Vertical line.
      if (_isEmpty(matrix[6][i])) {
        matrix[6][i] = bit;
      }
    }
  }

  // Embed the lonely dark dot at left bottom corner. JISX0510:2004 (p.46)
  void _embedDarkDotAtLeftBottomCorner() {
    if (matrix[8][matrix.height - 8] == 0) {
      throw WriterException();
    }
    matrix[8][matrix.height - 8] = 1 << version.compression.level;
  }

  void _embedHorizontalSeparationPattern(int xStart, int yStart) {
    for (int x = 0; x < 8; ++x) {
      if (!_isEmpty(matrix[xStart + x][yStart])) {
        throw WriterException();
      }
      matrix[xStart + x][yStart] = 0;
    }
  }

  void _embedVerticalSeparationPattern(int xStart, int yStart) {
    for (int y = 0; y < 7; ++y) {
      if (!_isEmpty(matrix[xStart][yStart + y])) {
        throw WriterException();
      }
      matrix[xStart][yStart + y] = 0;
    }
  }

  void _embedPositionAdjustmentPattern(int xStart, int yStart) {
    for (int y = 0; y < 5; ++y) {
      final patternY = _positionAdjustmentPattern[y];
      for (int x = 0; x < 5; ++x) {
        matrix[xStart + x][yStart + y] =
            patternY[x] << version.compression.level;
      }
    }
  }

  void _embedPositionDetectionPattern(int xStart, int yStart) {
    for (int y = 0; y < 7; ++y) {
      final patternY = _positionDetectionPattern[y];
      for (int x = 0; x < 7; ++x) {
        matrix[xStart + x][yStart + y] =
            patternY[x] << version.compression.level;
      }
    }
  }

  // Embed position detection patterns and surrounding vertical/horizontal separators.
  void _embedPositionDetectionPatternsAndSeparators() {
    // Embed three big squares at corners.
    final pdpWidth = _positionDetectionPattern[0].length;
    // Left top corner.
    _embedPositionDetectionPattern(0, 0);
    // Right top corner.
    _embedPositionDetectionPattern(matrix.width - pdpWidth, 0);
    // Left bottom corner.
    _embedPositionDetectionPattern(0, matrix.width - pdpWidth);

    // Embed horizontal separation patterns around the squares.
    const hspWidth = 8;
    // Left top corner.
    _embedHorizontalSeparationPattern(0, hspWidth - 1);
    // Right top corner.
    _embedHorizontalSeparationPattern(matrix.width - hspWidth, hspWidth - 1);
    // Left bottom corner.
    _embedHorizontalSeparationPattern(0, matrix.width - hspWidth);

    // Embed vertical separation patterns around the squares.
    const vspSize = 7;
    // Left top corner.
    _embedVerticalSeparationPattern(vspSize, 0);
    // Right top corner.
    _embedVerticalSeparationPattern(matrix.height - vspSize - 1, 0);
    // Left bottom corner.
    _embedVerticalSeparationPattern(vspSize, matrix.height - vspSize);
  }

  // Embed position adjustment patterns if need be.
  void _maybeEmbedPositionAdjustmentPatterns() {
    if (version.number < 2) {
      // The patterns appear if version >= 2
      return;
    }
    final coordinates = version.alignmentPatternCenters;
    for (int y in coordinates) {
      for (int x in coordinates) {
        if (_isEmpty(matrix[x][y])) {
          // If the cell is unset, we embed the position adjustment pattern here.
          // -2 is necessary since the x/y coordinates point to the center of the pattern, not the
          // left top corner.
          _embedPositionAdjustmentPattern(x - 2, y - 2);
        }
      }
    }
  }

  static const List<List<int>> _positionDetectionPattern = [
    [1, 1, 1, 1, 1, 1, 1],
    [1, 0, 0, 0, 0, 0, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 0, 1, 1, 1, 0, 1],
    [1, 0, 0, 0, 0, 0, 1],
    [1, 1, 1, 1, 1, 1, 1],
  ];

  static const List<List<int>> _positionAdjustmentPattern = [
    [1, 1, 1, 1, 1],
    [1, 0, 0, 0, 1],
    [1, 0, 1, 0, 1],
    [1, 0, 0, 0, 1],
    [1, 1, 1, 1, 1],
  ];

  // Type info cells at the left top corner.
  static const List<List<int>> _typeInfoCoordinates = [
    [8, 0],
    [8, 1],
    [8, 2],
    [8, 3],
    [8, 4],
    [8, 5],
    [8, 7],
    [8, 8],
    [7, 8],
    [5, 8],
    [4, 8],
    [3, 8],
    [2, 8],
    [1, 8],
    [0, 8],
  ];
}
