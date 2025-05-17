/*
 * Copyright 2009 ZXing authors
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

import '../core/byte4_matrix.dart';
import '../exceptions/not_found_exception.dart';

/// This Binarizer implementation uses the old ZXing global histogram approach.
///
/// It is suitable for low-end mobile devices which don't have enough CPU or memory to use a local thresholding
/// algorithm. However, because it picks a global black point, it cannot handle difficult shadows
/// and gradients.
///
/// Faster mobile devices and all desktop applications should probably use HybridBinarizer instead.
///
/// @author dswitkin@google.com (Daniel Switkin)
/// @author Sean Owen
class GlobalHistogramBinarizer {
  static const int _luminanceBits = 5;
  static const int _luminanceShift = 8 - _luminanceBits;
  static const int _luminanceBuckets = 1 << _luminanceBits;
  static final Uint8List _empty = Uint8List(0);

  Uint8List _luminances;
  final List<int> _buckets;

  Byte4Matrix image;

  GlobalHistogramBinarizer(this.image)
      : _luminances = _empty,
        _buckets = List.filled(_luminanceBuckets, 0);

  // Does not sharpen the data, as this call is intended to only be used by 2D Readers.

  Byte4Matrix get blackMatrix {
    final width = image.width;
    final height = image.height;

    // Quickly calculates the histogram by sampling four rows from the image. This proved to be
    // more robust on the blackbox tests than sampling a diagonal as we used to do.
    _initArrays(width);
    final localBuckets = _buckets;
    // for (int y = 1; y < 5; y++) {
    //   final row = height * y ~/ 5;
    //   final localLuminances = image[row]; //I know
    //   final right = (width * 4) ~/ 5;
    //   for (int x = width ~/ 5; x < right; x++) {
    //     final pixel = localLuminances[x] & 0xFF;
    //     localBuckets[pixel >> _luminanceShift]++;
    //   }
    // }
    // columns now
    for (int x = 1; x < 5; x++) {
      final column = width * x ~/ 5;
      final localLuminances = image[column];
      final bottom = (height * 4) ~/ 5;
      for (int y = height ~/ 5; y < bottom; y++) {
        final pixel = localLuminances[y] & 0xFF;
        localBuckets[pixel >> _luminanceShift]++;
      }
    }

    final blackPoint = _estimateBlackPoint(localBuckets);

    // We delay reading the entire image luminance until the black point estimation succeeds.
    // Although we end up reading four rows twice, it is consistent with our motto of
    // "fail quickly" which is necessary for continuous scanning.
    final localLuminances = image;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = localLuminances[x][y];

        image[x][y] =
            (pixel & 0xFFFFFF00) | ((pixel & 0xFF) <= blackPoint ? 1 : 0);
      }
    }

    return image;
  }

  void _initArrays(int luminanceSize) {
    if (_luminances.length < luminanceSize) {
      _luminances = Uint8List(luminanceSize);
    }
    _buckets.fillRange(0, _luminanceBuckets, 0);
  }

  static int _estimateBlackPoint(List<int> buckets) {
    // Find the tallest peak in the histogram.
    final numBuckets = buckets.length;
    int maxBucketCount = 0;
    int firstPeak = 0;
    int firstPeakSize = 0;
    for (int x = 0; x < numBuckets; x++) {
      if (buckets[x] > firstPeakSize) {
        firstPeak = x;
        firstPeakSize = buckets[x];
      }
      if (buckets[x] > maxBucketCount) {
        maxBucketCount = buckets[x];
      }
    }

    // Find the second-tallest peak which is somewhat far from the tallest peak.
    int secondPeak = 0;
    int secondPeakScore = 0;
    for (int x = 0; x < numBuckets; x++) {
      final distanceToBiggest = x - firstPeak;
      // Encourage more distant second peaks by multiplying by square of distance.
      final score = buckets[x] * distanceToBiggest * distanceToBiggest;
      if (score > secondPeakScore) {
        secondPeak = x;
        secondPeakScore = score;
      }
    }

    // Make sure firstPeak corresponds to the black peak.
    if (firstPeak > secondPeak) {
      final temp = firstPeak;
      firstPeak = secondPeak;
      secondPeak = temp;
    }

    // If there is too little contrast in the image to pick a meaningful black point, throw rather
    // than waste time trying to decode the image, and risk false positives.
    if (secondPeak - firstPeak <= numBuckets / 16) {
      throw NotFoundException.instance;
    }

    // Find a valley between them that is low and closer to the white peak.
    int bestValley = secondPeak - 1;
    int bestValleyScore = -1;
    for (int x = secondPeak - 1; x > firstPeak; x--) {
      final fromFirst = x - firstPeak;
      final score = fromFirst *
          fromFirst *
          (secondPeak - x) *
          (maxBucketCount - buckets[x]);
      if (score > bestValleyScore) {
        bestValley = x;
        bestValleyScore = score;
      }
    }

    return bestValley << _luminanceShift;
  }
}
