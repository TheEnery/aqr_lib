/*
 * Copyright 2025 TheEnery
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

import '../extensions/int_extension.dart';

import 'error_correction.dart';
import 'mask.dart';

/// Used for encoding/decoding format information,
/// which includes error correction and mask.
class FormatInformation {
  /// Format information mask pattern.
  static const int maskBits = 0x5412;

  /// Bit count of format information.
  static const int bitCount = 15;

  final ErrorCorrection errorCorrection;
  final Mask mask;

  FormatInformation({required this.errorCorrection, required this.mask});

  FormatInformation.fromDecodedBits(int bits)
      : errorCorrection = ErrorCorrection.fromBits((bits >> 3) & 0x03),
        mask = Mask(number: bits & 0x07);

  int get decodedBits => (errorCorrection.bits << 3) | mask.number;
  int get encodedBits => _encodeLookup[decodedBits];

  static FormatInformation? tryDecode(int bits) {
    var lowestDifferentBitCount = 0xFF;
    var nearestDecodedBits = 0;
    for (int decodedBits = 0;
        decodedBits < _encodeLookup.length;
        decodedBits++) {
      final encodedBits = _encodeLookup[decodedBits];
      if (bits == encodedBits) {
        return FormatInformation.fromDecodedBits(decodedBits);
      }

      final differentBitCount = (encodedBits ^ bits).bitCount32;
      if (differentBitCount < lowestDifferentBitCount) {
        lowestDifferentBitCount = differentBitCount;
        nearestDecodedBits = decodedBits;
      }
    }

    // According to ISO 18004:2015, Annex C, up to 3 errors can be corrected.
    if (lowestDifferentBitCount <= 3) {
      return FormatInformation.fromDecodedBits(nearestDecodedBits);
    }

    return null;
  }

  /// See ISO 18004:2006, Annex C, Table C.1.
  static const List<int> _encodeLookup = [
    0x5412,
    0x5125,
    0x5E7C,
    0x5B4B,
    0x45F9,
    0x40CE,
    0x4F97,
    0x4AA0,
    0x77C4,
    0x72F3,
    0x7DAA,
    0x789D,
    0x662F,
    0x6318,
    0x6C41,
    0x6976,
    0x1689,
    0x13BE,
    0x1CE7,
    0x19D0,
    0x0762,
    0x0255,
    0x0D0C,
    0x083B,
    0x355F,
    0x3068,
    0x3F31,
    0x3A06,
    0x24B4,
    0x2183,
    0x2EDA,
    0x2BED,
  ];
}
