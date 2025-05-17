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

import 'compression.dart';
import 'error_correction.dart';

class Version {
  static const int bitCount = 18;
  static const int minNumber = 1;
  static const int maxNumber = 40;

  final List<int> alignmentPatternCenters;
  final Compression compression;
  final EcbGroup ecbGroup;
  final ErrorCorrection errorCorrection;
  final int number;

  Version({
    required this.compression,
    required this.errorCorrection,
    required this.number,
  })  : alignmentPatternCenters =
            _VersionInformation.values[number - 1].alignmentPatternCenters,
        ecbGroup = _VersionInformation
            .values[number - 1].ecbGroups[errorCorrection.level]
            .copyExtended(compression);

  int get codewordCount => ecbGroup.dCodewordCount + ecbGroup.ecCodewordCount;
  int get dimension => 17 + 4 * number;
  int get encodedBits => _encodeLookup[number - 7];

  static int? tryDecodeNumber(int bits) {
    var lowestDifferentBitCount = 0xFF;
    var nearestDecodedBits = 0;
    for (int decodedBits = 0;
        decodedBits < _encodeLookup.length;
        decodedBits++) {
      final encodedBits = _encodeLookup[decodedBits];
      if (bits == encodedBits) {
        return decodedBits + 7;
      }

      final differentBitCount = (encodedBits ^ bits).bitCount32;
      if (differentBitCount < lowestDifferentBitCount) {
        lowestDifferentBitCount = differentBitCount;
        nearestDecodedBits = decodedBits;
      }
    }

    // According to ISO 18004:2015, Annex D, up to 3 errors can be corrected.
    if (lowestDifferentBitCount <= 3) {
      return nearestDecodedBits + 7;
    }

    return null;
  }

  static int? tryDeduceNumber(int dimension) {
    if (dimension % 4 != 1 ||
        17 + 4 * minNumber > dimension ||
        17 + 4 * maxNumber < dimension) return null;

    return (dimension - 17) ~/ 4;
  }

  /// See ISO 18004:2006 Annex D.
  /// Element i represents the raw version bits that specify version i + 7
  static const List<int> _encodeLookup = [
    0x07C94,
    0x085BC,
    0x09A99,
    0x0A4D3,
    0x0BBF6,
    0x0C762,
    0x0D847,
    0x0E60D,
    0x0F928,
    0x10B78,
    0x1145D,
    0x12A17,
    0x13532,
    0x149A6,
    0x15683,
    0x168C9,
    0x177EC,
    0x18EC4,
    0x191E1,
    0x1AFAB,
    0x1B08E,
    0x1CC1A,
    0x1D33F,
    0x1ED75,
    0x1F250,
    0x209D5,
    0x216F0,
    0x228BA,
    0x2379F,
    0x24B0B,
    0x2542E,
    0x26A64,
    0x27541,
    0x28C69,
  ];
}

/// A set of error correction blocks with the same number of corresponding
/// data codewords.
class SameEcb {
  /// The number of times such error correction block is repeated.
  final int repeatCount;

  /// The number of data codewords corresponding to each block.
  final int dCodewordsPerBlock;

  /// Creates the repeated [repeatCount] times error correction block
  /// with [dCodewordsPerBlock] corresponding data codewords.
  const SameEcb(this.repeatCount, this.dCodewordsPerBlock);
}

/// Contains all error correction blocks necessary
/// for a specific combination of [Version] and [ErrorCorrection].
///
/// Each error correction block may correspond to a different number of data
/// codewords, but all contain the same number of error correction codewords.
class EcbGroup {
  /// The error correction blocks.
  final List<SameEcb> ecBlocks;

  /// The number of error correction codewords per each block.
  final int ecCodewordsPerBlock;

  /// Creates a complete group of error correction blocks
  /// with [ecCodewordsPerBlock] error correction codewords in each block.
  const EcbGroup(this.ecCodewordsPerBlock, this.ecBlocks);

  /// The number of corresponding data codewords.
  int get dCodewordCount {
    int total = 0;
    for (final ecBlock in ecBlocks) {
      total += ecBlock.repeatCount * ecBlock.dCodewordsPerBlock;
    }
    return total;
  }

  /// The number of error correction blocks.
  int get ecBlockCount {
    int total = 0;
    for (final ecBlock in ecBlocks) {
      total += ecBlock.repeatCount;
    }
    return total;
  }

  /// The total number of error correction codewords.
  int get ecCodewordCount => ecCodewordsPerBlock * ecBlockCount;

  EcbGroup copyExtended(Compression compression) {
    final newEcBlocks = <SameEcb>[];
    for (final ecBlock in ecBlocks) {
      newEcBlocks.add(
        SameEcb(
          ecBlock.repeatCount * compression.bitsPerModule,
          ecBlock.dCodewordsPerBlock,
        ),
      );
    }
    return EcbGroup(ecCodewordsPerBlock, newEcBlocks);
  }
}

class _VersionInformation {
  final int number;
  final List<int> alignmentPatternCenters;
  final List<EcbGroup> ecbGroups;

  const _VersionInformation._(
    this.number,
    this.alignmentPatternCenters,
    this.ecbGroups,
  );

  /// See ISO 18004:2006 6.5.1 Table 9
  static const List<_VersionInformation> values = [
    _VersionInformation._(
      1,
      [],
      [
        EcbGroup(7, [SameEcb(1, 19)]),
        // example: there is single ec block that takes 16 data codeword and make 10 ec codewords
        // 26 codewords in total, just like for other ec levels
        EcbGroup(10, [SameEcb(1, 16)]),
        EcbGroup(13, [SameEcb(1, 13)]),
        EcbGroup(17, [SameEcb(1, 9)]),
      ],
    ),
    _VersionInformation._(
      2,
      [6, 18],
      [
        EcbGroup(10, [SameEcb(1, 34)]),
        EcbGroup(16, [SameEcb(1, 28)]),
        EcbGroup(22, [SameEcb(1, 22)]),
        EcbGroup(28, [SameEcb(1, 16)]),
      ],
    ),
    _VersionInformation._(
      3,
      [6, 22],
      [
        // 15 + 55 == 2 * (22 + 13)
        EcbGroup(15, [SameEcb(1, 55)]),
        EcbGroup(26, [SameEcb(1, 44)]),
        EcbGroup(18, [SameEcb(2, 17)]),
        EcbGroup(22, [SameEcb(2, 13)]),
      ],
    ),
    _VersionInformation._(
      4,
      [6, 26],
      [
        EcbGroup(20, [SameEcb(1, 80)]),
        EcbGroup(18, [SameEcb(2, 32)]),
        EcbGroup(26, [SameEcb(2, 24)]),
        EcbGroup(16, [SameEcb(4, 9)]),
      ],
    ),
    _VersionInformation._(
      5,
      [6, 30],
      [
        // it gets harder
        // 26 + 108 == 134 == 2 * (11 + 22) + 2 * (12 + 22) == 66 + 68
        EcbGroup(26, [SameEcb(1, 108)]),
        EcbGroup(24, [SameEcb(2, 43)]),
        EcbGroup(18, [SameEcb(2, 15), SameEcb(2, 16)]),
        EcbGroup(22, [SameEcb(2, 11), SameEcb(2, 12)]),
      ],
    ),
    _VersionInformation._(
      6,
      [6, 34],
      [
        EcbGroup(18, [SameEcb(2, 68)]),
        EcbGroup(16, [SameEcb(4, 27)]),
        EcbGroup(24, [SameEcb(4, 19)]),
        EcbGroup(28, [SameEcb(4, 15)]),
      ],
    ),
    _VersionInformation._(
      7,
      [6, 22, 38],
      [
        EcbGroup(20, [SameEcb(2, 78)]),
        EcbGroup(18, [SameEcb(4, 31)]),
        EcbGroup(18, [SameEcb(2, 14), SameEcb(4, 15)]),
        EcbGroup(26, [SameEcb(4, 13), SameEcb(1, 14)]),
      ],
    ),
    _VersionInformation._(
      8,
      [6, 24, 42],
      [
        EcbGroup(24, [SameEcb(2, 97)]),
        EcbGroup(22, [SameEcb(2, 38), SameEcb(2, 39)]),
        EcbGroup(22, [SameEcb(4, 18), SameEcb(2, 19)]),
        EcbGroup(26, [SameEcb(4, 14), SameEcb(2, 15)]),
      ],
    ),
    _VersionInformation._(
      9,
      [6, 26, 46],
      [
        EcbGroup(30, [SameEcb(2, 116)]),
        EcbGroup(22, [SameEcb(3, 36), SameEcb(2, 37)]),
        EcbGroup(20, [SameEcb(4, 16), SameEcb(4, 17)]),
        EcbGroup(24, [SameEcb(4, 12), SameEcb(4, 13)]),
      ],
    ),
    _VersionInformation._(
      10,
      [6, 28, 50],
      [
        EcbGroup(18, [SameEcb(2, 68), SameEcb(2, 69)]),
        EcbGroup(26, [SameEcb(4, 43), SameEcb(1, 44)]),
        EcbGroup(24, [SameEcb(6, 19), SameEcb(2, 20)]),
        EcbGroup(28, [SameEcb(6, 15), SameEcb(2, 16)]),
      ],
    ),
    _VersionInformation._(
      11,
      [6, 30, 54],
      [
        EcbGroup(20, [SameEcb(4, 81)]),
        EcbGroup(30, [SameEcb(1, 50), SameEcb(4, 51)]),
        EcbGroup(28, [SameEcb(4, 22), SameEcb(4, 23)]),
        EcbGroup(24, [SameEcb(3, 12), SameEcb(8, 13)]),
      ],
    ),
    _VersionInformation._(
      12,
      [6, 32, 58],
      [
        EcbGroup(24, [SameEcb(2, 92), SameEcb(2, 93)]),
        EcbGroup(22, [SameEcb(6, 36), SameEcb(2, 37)]),
        EcbGroup(26, [SameEcb(4, 20), SameEcb(6, 21)]),
        EcbGroup(28, [SameEcb(7, 14), SameEcb(4, 15)]),
      ],
    ),
    _VersionInformation._(
      13,
      [6, 34, 62],
      [
        EcbGroup(26, [SameEcb(4, 107)]),
        EcbGroup(22, [SameEcb(8, 37), SameEcb(1, 38)]),
        EcbGroup(24, [SameEcb(8, 20), SameEcb(4, 21)]),
        EcbGroup(22, [SameEcb(12, 11), SameEcb(4, 12)]),
      ],
    ),
    _VersionInformation._(
      14,
      [6, 26, 46, 66],
      [
        EcbGroup(30, [SameEcb(3, 115), SameEcb(1, 116)]),
        EcbGroup(24, [SameEcb(4, 40), SameEcb(5, 41)]),
        EcbGroup(20, [SameEcb(11, 16), SameEcb(5, 17)]),
        EcbGroup(24, [SameEcb(11, 12), SameEcb(5, 13)]),
      ],
    ),
    _VersionInformation._(
      15,
      [6, 26, 48, 70],
      [
        EcbGroup(22, [SameEcb(5, 87), SameEcb(1, 88)]),
        EcbGroup(24, [SameEcb(5, 41), SameEcb(5, 42)]),
        EcbGroup(30, [SameEcb(5, 24), SameEcb(7, 25)]),
        EcbGroup(24, [SameEcb(11, 12), SameEcb(7, 13)]),
      ],
    ),
    _VersionInformation._(
      16,
      [6, 26, 50, 74],
      [
        EcbGroup(24, [SameEcb(5, 98), SameEcb(1, 99)]),
        EcbGroup(28, [SameEcb(7, 45), SameEcb(3, 46)]),
        EcbGroup(24, [SameEcb(15, 19), SameEcb(2, 20)]),
        EcbGroup(30, [SameEcb(3, 15), SameEcb(13, 16)]),
      ],
    ),
    _VersionInformation._(
      17,
      [6, 30, 54, 78],
      [
        EcbGroup(28, [SameEcb(1, 107), SameEcb(5, 108)]),
        EcbGroup(28, [SameEcb(10, 46), SameEcb(1, 47)]),
        EcbGroup(28, [SameEcb(1, 22), SameEcb(15, 23)]),
        EcbGroup(28, [SameEcb(2, 14), SameEcb(17, 15)]),
      ],
    ),
    _VersionInformation._(
      18,
      [6, 30, 56, 82],
      [
        EcbGroup(30, [SameEcb(5, 120), SameEcb(1, 121)]),
        EcbGroup(26, [SameEcb(9, 43), SameEcb(4, 44)]),
        EcbGroup(28, [SameEcb(17, 22), SameEcb(1, 23)]),
        EcbGroup(28, [SameEcb(2, 14), SameEcb(19, 15)]),
      ],
    ),
    _VersionInformation._(
      19,
      [6, 30, 58, 86],
      [
        EcbGroup(28, [SameEcb(3, 113), SameEcb(4, 114)]),
        EcbGroup(26, [SameEcb(3, 44), SameEcb(11, 45)]),
        EcbGroup(26, [SameEcb(17, 21), SameEcb(4, 22)]),
        EcbGroup(26, [SameEcb(9, 13), SameEcb(16, 14)]),
      ],
    ),
    _VersionInformation._(
      20,
      [6, 34, 62, 90],
      [
        EcbGroup(28, [SameEcb(3, 107), SameEcb(5, 108)]),
        EcbGroup(26, [SameEcb(3, 41), SameEcb(13, 42)]),
        EcbGroup(30, [SameEcb(15, 24), SameEcb(5, 25)]),
        EcbGroup(28, [SameEcb(15, 15), SameEcb(10, 16)]),
      ],
    ),
    _VersionInformation._(
      21,
      [6, 28, 50, 72, 94],
      [
        EcbGroup(28, [SameEcb(4, 116), SameEcb(4, 117)]),
        EcbGroup(26, [SameEcb(17, 42)]),
        EcbGroup(28, [SameEcb(17, 22), SameEcb(6, 23)]),
        EcbGroup(30, [SameEcb(19, 16), SameEcb(6, 17)]),
      ],
    ),
    _VersionInformation._(
      22,
      [6, 26, 50, 74, 98],
      [
        EcbGroup(28, [SameEcb(2, 111), SameEcb(7, 112)]),
        EcbGroup(28, [SameEcb(17, 46)]),
        EcbGroup(30, [SameEcb(7, 24), SameEcb(16, 25)]),
        EcbGroup(24, [SameEcb(34, 13)]),
      ],
    ),
    _VersionInformation._(
      23,
      [6, 30, 54, 78, 102],
      [
        EcbGroup(30, [SameEcb(4, 121), SameEcb(5, 122)]),
        EcbGroup(28, [SameEcb(4, 47), SameEcb(14, 48)]),
        EcbGroup(30, [SameEcb(11, 24), SameEcb(14, 25)]),
        EcbGroup(30, [SameEcb(16, 15), SameEcb(14, 16)]),
      ],
    ),
    _VersionInformation._(
      24,
      [6, 28, 54, 80, 106],
      [
        EcbGroup(30, [SameEcb(6, 117), SameEcb(4, 118)]),
        EcbGroup(28, [SameEcb(6, 45), SameEcb(14, 46)]),
        EcbGroup(30, [SameEcb(11, 24), SameEcb(16, 25)]),
        EcbGroup(30, [SameEcb(30, 16), SameEcb(2, 17)]),
      ],
    ),
    _VersionInformation._(
      25,
      [6, 32, 58, 84, 110],
      [
        EcbGroup(26, [SameEcb(8, 106), SameEcb(4, 107)]),
        EcbGroup(28, [SameEcb(8, 47), SameEcb(13, 48)]),
        EcbGroup(30, [SameEcb(7, 24), SameEcb(22, 25)]),
        EcbGroup(30, [SameEcb(22, 15), SameEcb(13, 16)]),
      ],
    ),
    _VersionInformation._(
      26,
      [6, 30, 58, 86, 114],
      [
        EcbGroup(28, [SameEcb(10, 114), SameEcb(2, 115)]),
        EcbGroup(28, [SameEcb(19, 46), SameEcb(4, 47)]),
        EcbGroup(28, [SameEcb(28, 22), SameEcb(6, 23)]),
        EcbGroup(30, [SameEcb(33, 16), SameEcb(4, 17)]),
      ],
    ),
    _VersionInformation._(
      27,
      [6, 34, 62, 90, 118],
      [
        EcbGroup(30, [SameEcb(8, 122), SameEcb(4, 123)]),
        EcbGroup(28, [SameEcb(22, 45), SameEcb(3, 46)]),
        EcbGroup(30, [SameEcb(8, 23), SameEcb(26, 24)]),
        EcbGroup(30, [SameEcb(12, 15), SameEcb(28, 16)]),
      ],
    ),
    _VersionInformation._(
      28,
      [6, 26, 50, 74, 98, 122],
      [
        EcbGroup(30, [SameEcb(3, 117), SameEcb(10, 118)]),
        EcbGroup(28, [SameEcb(3, 45), SameEcb(23, 46)]),
        EcbGroup(30, [SameEcb(4, 24), SameEcb(31, 25)]),
        EcbGroup(30, [SameEcb(11, 15), SameEcb(31, 16)]),
      ],
    ),
    _VersionInformation._(
      29,
      [6, 30, 54, 78, 102, 126],
      [
        EcbGroup(30, [SameEcb(7, 116), SameEcb(7, 117)]),
        EcbGroup(28, [SameEcb(21, 45), SameEcb(7, 46)]),
        EcbGroup(30, [SameEcb(1, 23), SameEcb(37, 24)]),
        EcbGroup(30, [SameEcb(19, 15), SameEcb(26, 16)]),
      ],
    ),
    _VersionInformation._(
      30,
      [6, 26, 52, 78, 104, 130],
      [
        EcbGroup(30, [SameEcb(5, 115), SameEcb(10, 116)]),
        EcbGroup(28, [SameEcb(19, 47), SameEcb(10, 48)]),
        EcbGroup(30, [SameEcb(15, 24), SameEcb(25, 25)]),
        EcbGroup(30, [SameEcb(23, 15), SameEcb(25, 16)]),
      ],
    ),
    _VersionInformation._(
      31,
      [6, 30, 56, 82, 108, 134],
      [
        EcbGroup(30, [SameEcb(13, 115), SameEcb(3, 116)]),
        EcbGroup(28, [SameEcb(2, 46), SameEcb(29, 47)]),
        EcbGroup(30, [SameEcb(42, 24), SameEcb(1, 25)]),
        EcbGroup(30, [SameEcb(23, 15), SameEcb(28, 16)]),
      ],
    ),
    _VersionInformation._(
      32,
      [6, 34, 60, 86, 112, 138],
      [
        EcbGroup(30, [SameEcb(17, 115)]),
        EcbGroup(28, [SameEcb(10, 46), SameEcb(23, 47)]),
        EcbGroup(30, [SameEcb(10, 24), SameEcb(35, 25)]),
        EcbGroup(30, [SameEcb(19, 15), SameEcb(35, 16)]),
      ],
    ),
    _VersionInformation._(
      33,
      [6, 30, 58, 86, 114, 142],
      [
        EcbGroup(30, [SameEcb(17, 115), SameEcb(1, 116)]),
        EcbGroup(28, [SameEcb(14, 46), SameEcb(21, 47)]),
        EcbGroup(30, [SameEcb(29, 24), SameEcb(19, 25)]),
        EcbGroup(30, [SameEcb(11, 15), SameEcb(46, 16)]),
      ],
    ),
    _VersionInformation._(
      34,
      [6, 34, 62, 90, 118, 146],
      [
        EcbGroup(30, [SameEcb(13, 115), SameEcb(6, 116)]),
        EcbGroup(28, [SameEcb(14, 46), SameEcb(23, 47)]),
        EcbGroup(30, [SameEcb(44, 24), SameEcb(7, 25)]),
        EcbGroup(30, [SameEcb(59, 16), SameEcb(1, 17)]),
      ],
    ),
    _VersionInformation._(
      35,
      [6, 30, 54, 78, 102, 126, 150],
      [
        EcbGroup(30, [SameEcb(12, 121), SameEcb(7, 122)]),
        EcbGroup(28, [SameEcb(12, 47), SameEcb(26, 48)]),
        EcbGroup(30, [SameEcb(39, 24), SameEcb(14, 25)]),
        EcbGroup(30, [SameEcb(22, 15), SameEcb(41, 16)]),
      ],
    ),
    _VersionInformation._(
      36,
      [6, 24, 50, 76, 102, 128, 154],
      [
        EcbGroup(30, [SameEcb(6, 121), SameEcb(14, 122)]),
        EcbGroup(28, [SameEcb(6, 47), SameEcb(34, 48)]),
        EcbGroup(30, [SameEcb(46, 24), SameEcb(10, 25)]),
        EcbGroup(30, [SameEcb(2, 15), SameEcb(64, 16)]),
      ],
    ),
    _VersionInformation._(
      37,
      [6, 28, 54, 80, 106, 132, 158],
      [
        EcbGroup(30, [SameEcb(17, 122), SameEcb(4, 123)]),
        EcbGroup(28, [SameEcb(29, 46), SameEcb(14, 47)]),
        EcbGroup(30, [SameEcb(49, 24), SameEcb(10, 25)]),
        EcbGroup(30, [SameEcb(24, 15), SameEcb(46, 16)]),
      ],
    ),
    _VersionInformation._(
      38,
      [6, 32, 58, 84, 110, 136, 162],
      [
        EcbGroup(30, [SameEcb(4, 122), SameEcb(18, 123)]),
        EcbGroup(28, [SameEcb(13, 46), SameEcb(32, 47)]),
        EcbGroup(30, [SameEcb(48, 24), SameEcb(14, 25)]),
        EcbGroup(30, [SameEcb(42, 15), SameEcb(32, 16)]),
      ],
    ),
    _VersionInformation._(
      39,
      [6, 26, 54, 82, 110, 138, 166],
      [
        EcbGroup(30, [SameEcb(20, 117), SameEcb(4, 118)]),
        EcbGroup(28, [SameEcb(40, 47), SameEcb(7, 48)]),
        EcbGroup(30, [SameEcb(43, 24), SameEcb(22, 25)]),
        EcbGroup(30, [SameEcb(10, 15), SameEcb(67, 16)]),
      ],
    ),
    _VersionInformation._(
      40,
      [6, 30, 58, 86, 114, 142, 170],
      [
        EcbGroup(30, [SameEcb(19, 118), SameEcb(6, 119)]),
        EcbGroup(28, [SameEcb(18, 47), SameEcb(31, 48)]),
        EcbGroup(30, [SameEcb(34, 24), SameEcb(34, 25)]),
        EcbGroup(30, [SameEcb(20, 15), SameEcb(61, 16)]),
      ],
    ),
  ];
}
