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

import 'dart:typed_data';

import 'package:aqr_lib/src/encoder/segment.dart';

import '../core/aqr_code.dart';
import '../core/aqr_meta.dart';
import '../core/bit_writer.dart';
import '../core/dec_block_pair.dart';
import '../core/mask.dart';
import '../core/matrix_builder.dart';
import '../core/version.dart';
import '../reedsolomon/generic_gf.dart';
import '../reedsolomon/reed_solomon_encoder.dart';

import 'codewords_constructor.dart';
import 'mask_penalty_calculator.dart';

class Encoder {
  late AqrMeta meta;
  late Version version;

  AqrCode encodeSegments({required List<Segment> data, required AqrMeta meta}) {
    this.meta = meta;

    final constructor = CodewordsConstructor.fromSegments(data);

    version = chooseVersion(constructor);

    final codewords = constructor.makeCodewords(version);

    final interleaved = interleaveWithEcBytes(codewords);

    final finalBits = BitWriter.from(interleaved);

    final builder = MatrixBuilder(version: version);

    final mask = meta.mask ?? chooseMask(finalBits, builder);

    builder.buildMatrix(data: finalBits.reader, mask: mask);

    return AqrCode(data: builder.matrix, meta: meta);
  }

  AqrCode encode({required String data, required AqrMeta meta}) {
    this.meta = meta;

    final constructor = CodewordsConstructor()..addContent(data);

    version = chooseVersion(constructor);

    final codewords = constructor.makeCodewords(version);

    final interleaved = interleaveWithEcBytes(codewords);

    final finalBits = BitWriter.from(interleaved);

    final builder = MatrixBuilder(version: version);

    final mask = meta.mask ?? chooseMask(finalBits, builder);

    builder.buildMatrix(data: finalBits.reader, mask: mask);

    return AqrCode(data: builder.matrix, meta: meta);
  }

  Mask chooseMask(BitWriter bits, MatrixBuilder builder) {
    var minPenalty = 0xFFFFFFFF;
    var bestMask = Mask(number: 0);
    final penaltyCalculator = MaskPenaltyCalculator(builder.matrix);

    for (final mask in Mask.values) {
      builder.buildMatrix(data: bits.reader, mask: mask);
      final penalty = penaltyCalculator.calculatePenalty();
      if (penalty < minPenalty) {
        minPenalty = penalty;
        bestMask = mask;
      }
    }
    return bestMask;
  }

  Version chooseVersion(CodewordsConstructor constructor) {
    for (int i = 1; i <= 40; i++) {
      final version = Version(
        errorCorrection: meta.errorCorrection,
        number: i,
        compression: meta.compression,
      );
      final dataCapacity = version.ecbGroup.dCodewordCount * 8;
      final dataSize = constructor.calculateDataSize(version);

      if (dataSize <= dataCapacity) {
        return version;
      }
    }
    throw Exception();
  }

  /// Interleave data bytes with corresponding error correction bytes.
  /// See 8.6 of JISX0510:2004 (p.37) for details.
  Uint8List interleaveWithEcBytes(Uint8List bytes) {
    final ecbGroup = version.ecbGroup;
    final dByteCount = ecbGroup.dCodewordCount;

    if (bytes.length != dByteCount) {
      throw StateError('$dByteCount bytes expected, but got ${bytes.length}');
    }

    int dataBytesOffset = 0;
    int maxDataByteCount = 0;
    final blocks = <DecBlockPair>[];

    for (final ecb in ecbGroup.ecBlocks) {
      final dSize = ecb.dCodewordsPerBlock;
      if (maxDataByteCount < dSize) maxDataByteCount = dSize;

      for (int i = 0; i < ecb.repeatCount; i++) {
        final dBytes = bytes.sublist(dataBytesOffset, dataBytesOffset + dSize);
        final ecBytes = Uint8List.fromList(
          _rsEncoder.encode(dBytes, ecbGroup.ecCodewordsPerBlock),
        );

        blocks.add(DecBlockPair(dBytes, ecBytes));
        dataBytesOffset += dSize;
      }
    }

    if (dByteCount != dataBytesOffset) {
      throw StateError(
        '$dByteCount bytes should be consumed, '
        'but only $dataBytesOffset bytes were',
      );
    }

    final decByteCount = dByteCount + ecbGroup.ecCodewordCount;
    final result = Uint8List(decByteCount);
    var index = 0;

    // First, place data blocks.
    for (int i = 0; i < maxDataByteCount; i++) {
      for (final block in blocks) {
        final dataBytes = block.dataCodewords;
        if (i < dataBytes.length) {
          result[index++] = dataBytes[i];
        }
      }
    }

    // Then, place error correction blocks.
    for (int i = 0; i < ecbGroup.ecCodewordsPerBlock; i++) {
      for (final block in blocks) {
        result[index++] = block.errorCorrectionCodewords[i];
      }
    }

    return result;
  }

  static final _rsEncoder = ReedSolomonEncoder(GenericGF.qrCodeField256);
}
