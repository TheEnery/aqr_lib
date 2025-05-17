/*
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

import 'dart:typed_data';

import '../core/byte_matrix.dart';

/// @author Satoru Takabayashi
/// @author Daniel Switkin
/// @author Sean Owen
class MaskPenaltyCalculator {
  // Penalty weights from section 6.8.2.1
  static const int _n1 = 3;
  static const int _n2 = 3;
  static const int _n3 = 40;
  static const int _n4 = 10;

  final ByteMatrix matrix;

  MaskPenaltyCalculator(this.matrix);

  int calculatePenalty() =>
      applyMaskPenaltyRule1() +
      applyMaskPenaltyRule2() +
      applyMaskPenaltyRule3() +
      applyMaskPenaltyRule4();

  /// Apply mask penalty rule 1 and return the penalty. Find repetitive cells with the same color and
  /// give penalty to them. Example: 00000 or 11111.
  int applyMaskPenaltyRule1() {
    return _applyMaskPenaltyRule1Internal(true) +
        _applyMaskPenaltyRule1Internal(false);
  }

  /// Apply mask penalty rule 2 and return the penalty. Find 2x2 blocks with the same color and give
  /// penalty to them. This is actually equivalent to the spec's rule, which is to find MxN blocks and give a
  /// penalty proportional to (M-1)x(N-1), because this is the number of 2x2 blocks inside such a block.
  int applyMaskPenaltyRule2() {
    int penalty = 0;
    final width = matrix.width;
    final height = matrix.height;
    for (int x = 0; x < width - 1; x++) {
      final thisColumn = matrix[x];
      final nextColumn = matrix[x + 1];
      for (int y = 0; y < height - 1; y++) {
        final value = thisColumn[y];
        if (value == thisColumn[y + 1] &&
            value == nextColumn[y] &&
            value == nextColumn[y + 1]) {
          penalty++;
        }
      }
    }
    return _n2 * penalty;
  }

  /// Apply mask penalty rule 3 and return the penalty. Find consecutive runs of 1:1:3:1:1:4
  /// starting with black, or 4:1:1:3:1:1 starting with white, and give penalty to them.  If we
  /// find patterns like 000010111010000, we give penalty once.
  int applyMaskPenaltyRule3() {
    int numPenalties = 0;
    final width = matrix.width;
    final height = matrix.height;
    for (int x = 0; x < width; x++) {
      final column = matrix[x];
      for (int y = 0; y < height; y++) {
        if (y + 6 < height &&
            column[y + 0] == 1 &&
            column[y + 1] == 0 &&
            column[y + 2] == 1 &&
            column[y + 3] == 1 &&
            column[y + 4] == 1 &&
            column[y + 5] == 0 &&
            column[y + 6] == 1 &&
            (_isWhiteVertical(column, y - 4, y) ||
                _isWhiteVertical(column, y + 7, y + 11))) {
          numPenalties++;
        }
        if (x + 6 < width &&
            matrix[x + 0][y] == 1 &&
            matrix[x + 1][y] == 0 &&
            matrix[x + 2][y] == 1 &&
            matrix[x + 3][y] == 1 &&
            matrix[x + 4][y] == 1 &&
            matrix[x + 5][y] == 0 &&
            matrix[x + 6][y] == 1 &&
            (_isWhiteHorizontal(y, x - 4, x) ||
                _isWhiteHorizontal(y, x + 7, x + 11))) {
          numPenalties++;
        }
      }
    }
    return numPenalties * _n3;
  }

  bool _isWhiteHorizontal(int y, int from, int to) {
    if (from < 0 || matrix.width < to) {
      return false;
    }
    for (int i = from; i < to; i++) {
      if (matrix[i][y] == 1) {
        return false;
      }
    }
    return true;
  }

  bool _isWhiteVertical(Uint8List column, int from, int to) {
    if (from < 0 || column.length < to) {
      return false;
    }
    for (int i = from; i < to; i++) {
      if (column[i] == 1) {
        return false;
      }
    }
    return true;
  }

  /// Apply mask penalty rule 4 and return the penalty. Calculate the ratio of dark cells and give
  /// penalty if the ratio is far from 50%. It gives 10 penalty for 5% distance.
  int applyMaskPenaltyRule4() {
    int numDarkCells = 0;
    final width = matrix.width;
    final height = matrix.height;
    for (int x = 0; x < width; x++) {
      final column = matrix[x];
      for (int y = 0; y < height; y++) {
        if (column[y] == 1) {
          numDarkCells++;
        }
      }
    }
    final numTotalCells = matrix.height * matrix.width;
    final fivePercentVariances =
        (numDarkCells * 2 - numTotalCells).abs() * 10 ~/ numTotalCells;
    return fivePercentVariances * _n4;
  }

  /// Helper function for applyMaskPenaltyRule1. We need this for doing this calculation in both
  /// vertical and horizontal orders respectively.
  int _applyMaskPenaltyRule1Internal(bool isHorizontal) {
    int penalty = 0;
    final iLimit = isHorizontal ? matrix.height : matrix.width;
    final jLimit = isHorizontal ? matrix.width : matrix.height;
    for (int i = 0; i < iLimit; i++) {
      int numSameBitCells = 0;
      int prevBit = -1;
      for (int j = 0; j < jLimit; j++) {
        final bit = isHorizontal ? matrix[i][j] : matrix[j][i];
        if (bit == prevBit) {
          numSameBitCells++;
        } else {
          if (numSameBitCells >= 5) {
            penalty += _n1 + (numSameBitCells - 5);
          }
          numSameBitCells = 1; // Include the cell itself.
          prevBit = bit;
        }
      }
      if (numSameBitCells >= 5) {
        penalty += _n1 + (numSameBitCells - 5);
      }
    }
    return penalty;
  }
}
