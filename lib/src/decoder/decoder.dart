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

import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:image/image.dart';

import 'package:aqr_lib/src/decoder/decoder_debug_info.dart';

import '../core/bit_writer.dart';
import '../core/byte4_matrix.dart';
import '../core/byte_matrix.dart';
import '../core/compression.dart';
import '../core/dec_block_pair.dart';
import '../decolorizer/unmap.dart';
import '../detector/detector.dart';
import '../detector/global_histogram_binarizer.dart';
import '../exceptions/checksum_exception.dart';
import '../exceptions/formats_exception.dart';
import '../exceptions/reed_solomon_exception.dart';
import '../reedsolomon/generic_gf.dart';
import '../reedsolomon/reed_solomon_decoder.dart';

import 'bit_matrix_parser.dart';
import 'decoded_bit_stream_parser.dart';
import 'decoder_result.dart';

/// The main class which implements QR Code decoding -- as opposed to locating and extracting
/// the QR Code from an image.
///
/// @author Sean Owen
class Decoder {
  static final ReedSolomonDecoder _rsDecoder =
      ReedSolomonDecoder(GenericGF.qrCodeField256);

  DecoderResult decode(Byte4Matrix image, {DecoderDebugInfo? debugInfo}) {
    final isDebugEnabled = debugInfo != null;
    final w = ColorRgb8(255, 255, 255), b = ColorRgb8(0, 0, 0);

    GlobalHistogramBinarizer(image).blackMatrix;

    if (isDebugEnabled) {
      final wbImage = Image(width: image.width, height: image.height);

      for (int x = 0; x < image.width; x++) {
        for (int y = 0; y < image.height; y++) {
          wbImage.setPixel(x, y, image[x][y] & 1 == 1 ? b : w);
        }
      }

      debugInfo.wbImage = wbImage;
    }

    final detected = Detector(image).detect().bits;

    if (isDebugEnabled) {
      final wbDetectedImage =
          Image(width: detected.width, height: detected.height);

      for (int x = 0; x < wbDetectedImage.width; x++) {
        for (int y = 0; y < wbDetectedImage.height; y++) {
          wbDetectedImage.setPixel(x, y, detected[x][y] & 1 == 1 ? b : w);
        }
      }

      debugInfo.wbDetectedImage = wbDetectedImage;

      debugInfo.detectedImage = detected.toImage();
    }

    detected.balanceColorsFromFinders();

    if (isDebugEnabled) {
      debugInfo.colorCorrectedImage = detected.toImage();
    }

    detected.applyGamma(2.2);

    // The hell starts here
    var colorDistribution = List.filled(360, 0);
    var lDistribution = List.generate(12, (i) => List.filled(100, 0));
    if (isDebugEnabled) {
      debugInfo.colorDistributionImage = Image(width: 360, height: 315);
    }

    // count colors
    for (int x = 0; x < detected.width; x++) {
      for (int y = 0; y < detected.height; y++) {
        final [_, r, g, b] = detected[x][y].to4ByteList();
        final [l, c, hShifted] = rgbToOklch(r, g, b);
        final h = ((hShifted - 30 + 360) % 360) / 360;

        if (l > 0.95 || l < 0.05 || c < .2) continue;

        colorDistribution[(h * 360).toInt()]++;

        final hInt = (h * 360).toInt();
        final idx = hInt ~/ 30;
        final lScaled = (l * 100).toInt();
        lDistribution[idx][lScaled]++;

        if (isDebugEnabled) {
          debugInfo.colorDistributionImage!
              .setPixelRgb((hInt + 30) % 360, 215 + lScaled, r, g, b);
        }
      }
    }

    // draw middle
    var maxH = colorDistribution.reduce(max);
    var maxL = lDistribution.map((e) => e.reduce(max)).reduce(max);
    if (isDebugEnabled) {
      for (int i = 0; i < colorDistribution.length; i++) {
        final color = oklchToRgb(((i + 30 + 360) % 360) / 360, 1, 0.5);
        final value = ((colorDistribution[i] / (maxH + 1)) * 100).toInt();
        final x = (i + 30) % 360;

        drawLine(
          debugInfo.colorDistributionImage!,
          x1: x,
          y1: 215 - value,
          x2: x,
          y2: 215,
          color: ColorRgb8(color[0], color[1], color[2]),
        );

        if (x % 60 == 0) {
          drawLine(
            debugInfo.colorDistributionImage!,
            x1: x,
            y1: 115,
            x2: x,
            y2: 215 - value,
            color: ColorRgb8(255, 255, 255),
          );
        }
      }
    }

    // analyze hues
    var colorCounts = [
      colorDistribution
          .sublist(330, 360)
          .followedBy(colorDistribution.sublist(0, 30))
          .toList()
    ]
        .followedBy(List.generate(
            5, (i) => colorDistribution.sublist(60 * i + 30, 60 * i + 90)))
        .map((cs) => cs.sum)
        .toList();

    final hThreshold = colorCounts.sum / colorCounts.length / 2;

    final dominantCount =
        (detected.height * detected.width / 8 > colorCounts.sum)
            ? 0
            : colorCounts.where((cc) => cc > hThreshold).length;

    var (compressionLevel, colorCount) = switch (dominantCount) {
      0 => (0, 0),
      1 => (1, 1),
      2 || 3 => (2, 3),
      4 || 5 || 6 => (3, 6),
      _ => throw StateError('Invalid dominant count'),
    };

    //(compressionLevel, colorCount) = (1, 1);

    List<HueSamplesRange> ranges = switch (compressionLevel) {
      0 => [],
      1 => [
          HueSamplesRange(
              0,
              360,
              colorDistribution,
              List.generate(
                  100, (j) => lDistribution.fold(0, (c, ls) => c + ls[j])))
        ],
      2 => (colorCounts[0] + colorCounts[2] + colorCounts[4] >
              colorCounts[1] + colorCounts[3] + colorCounts[5])
          ? [
              HueSamplesRange(
                  300,
                  60,
                  colorDistribution
                      .getRange(300, 360)
                      .followedBy(colorDistribution.getRange(0, 60))
                      .toList(),
                  List.generate(
                      100,
                      (j) => [
                            lDistribution[10],
                            lDistribution[11],
                            lDistribution[0],
                            lDistribution[1]
                          ].fold(0, (c, ls) => c + ls[j]))),
              HueSamplesRange(
                  60,
                  180,
                  colorDistribution.getRange(60, 180).toList(),
                  List.generate(
                      100,
                      (j) => lDistribution
                          .getRange(2, 6)
                          .fold(0, (c, ls) => c + ls[j]))),
              HueSamplesRange(
                  180,
                  300,
                  colorDistribution.getRange(180, 300).toList(),
                  List.generate(
                      100,
                      (j) => lDistribution
                          .getRange(6, 10)
                          .fold(0, (c, ls) => c + ls[j]))),
            ]
          : List.generate(
              3,
              (i) => HueSamplesRange(
                  i * 120,
                  i * 120 + 120,
                  colorDistribution.getRange(i * 120, i * 120 + 120).toList(),
                  List.generate(
                      100,
                      (j) => lDistribution
                          .getRange(i * 4, i * 4 + 4)
                          .fold(0, (c, ls) => c + ls[j])))),
      3 => [
          HueSamplesRange(
              330,
              30,
              colorDistribution
                  .sublist(330, 360)
                  .followedBy(colorDistribution.sublist(0, 30))
                  .toList(),
              List.generate(
                  100, (j) => lDistribution[0][j] + lDistribution[11][j]))
        ]
            .followedBy(List.generate(
                5,
                (i) => HueSamplesRange(
                    i * 60 + 30,
                    i * 60 + 90,
                    colorDistribution.sublist(i * 60 + 30, i * 60 + 90),
                    List.generate(
                        100,
                        (j) =>
                            lDistribution[i * 2 + 1][j] +
                            lDistribution[i * 2 + 2][j]))))
            .toList(),
      _ => throw StateError('How did you get here?'),
    };

    // opt make ls smooth
    for (int i = 0; i < ranges.length; i++) {
      final ls = ranges[i].ls;
      final newLs = List.filled(100, 0);
      final newLs2 = List.filled(100, 0);
      for (int j = 1; j < ls.length - 1; j++) {
        newLs[j] = (ls[j - 1] + ls[j] + ls[j + 1]) ~/ 3;
      }
      for (int j = 2; j < ls.length - 2; j++) {
        newLs2[j] = (newLs[j - 2] +
                newLs[j - 1] +
                newLs[j] +
                newLs[j + 1] +
                newLs[j + 2]) ~/
            5;
      }
      ranges[i].lsSmooth = newLs2;

      // find lThreshold
      //ranges[i].lThreshold
      var mid = (newLs2.lastIndexWhere((l) => l != 0) +
              newLs2.indexWhere((l) => l != 0)) ~/
          2;

      if (mid == -1) mid = 0;

      int thr = mid;
      final derivatives =
          List.generate(100, (i) => i == 99 ? 0 : newLs2[i + 1] - newLs2[i]);

      int mn = 0, mx = 99;

      if (derivatives[mid] == 0) {
        int l = mid, r = mid;

        while (l > mn && derivatives[l] == 0) l--;
        while (r < mx && derivatives[r] == 0) r++;

        if (derivatives[l] > 0 && derivatives[r] > 0) {
          thr = l;
        } else if (derivatives[l] < 0 && derivatives[r] < 0) {
          thr = r;
        }
      } else {}
      {
        int border = 0;
        if (derivatives[thr] < 0) {
          while (thr < mx && derivatives[thr] <= 0) thr++;
          if (thr == mx) {
            thr = mid;
          } else {
            border = thr - 1;
            while (border > mn && derivatives[border] == 0) border--;
            thr = (thr + border) ~/ 2;
          }
        } else {
          while (thr > mn && derivatives[thr] >= 0) thr--;
          if (thr == mn) {
            thr = mid;
          } else {
            border = thr + 1;
            while (border < mx && derivatives[border] == 0) border++;
            thr = (thr + border) ~/ 2;
          }
        }
      }

      ranges[i].lThreshold = thr;
    }

    // draw counts
    if (isDebugEnabled) {
      for (int i = 0; i < 6; i++) {
        final count = colorCounts[i];
        drawString(
          debugInfo.colorDistributionImage!,
          count.toString(),
          font: arial14,
          color: ColorRgb8(255, 255, 255),
          x: i * 60 + 25,
          y: 100,
        );
      }

      for (int i = 0; i < ranges.length; i++) {
        final width = 360 ~/ colorCount;
        final ls = ranges[i].lsSmooth;
        for (int j = 0; j < ls.length; j++) {
          final value = ((ls[j] / (maxL + 1)) * width).toInt();
          final color = oklchToRgb(
              ((ranges[i].start + width / 2 + 30) % 360) / 360, 1, j / 100);

          drawLine(
            debugInfo.colorDistributionImage!,
            x1: i * width,
            y1: j,
            x2: i * width + value,
            y2: j,
            color: ColorRgb8(color[0], color[1], color[2]),
          );
        }

        final value = ((ls[ranges[i].lThreshold] / maxL) * width).toInt();
        drawLine(debugInfo.colorDistributionImage!,
            x1: i * width + value,
            y1: ranges[i].lThreshold,
            x2: i * width + width,
            y2: ranges[i].lThreshold,
            color: ColorRgb8(255, 255, 255));
      }
    }

    final hTolThreshold = List.generate(
        360,
        (i) =>
            ranges
                .firstWhereOrNull((r) => (r.start < r.end)
                    ? r.start <= i && r.end > i
                    : r.start <= i || r.end > i)
                ?.lThreshold ??
            -1);
    final hToValue = List.generate(
        360,
        (i) =>
            1 +
            ranges.indexWhere((r) => (r.start < r.end)
                ? r.start <= i && r.end > i
                : r.start <= i || r.end > i));

    final decolorized =
        unmap2(detected, compressionLevel, hTolThreshold, hToValue);

    if (isDebugEnabled) {
      final correctedImage =
          Image(width: decolorized.width, height: decolorized.height);

      for (int x = 0; x < correctedImage.width; x++) {
        for (int y = 0; y < correctedImage.height; y++) {
          correctedImage.setPixel(x, y,
              Compression.defaultPalette[compressionLevel][decolorized[x][y]]);
        }
      }

      debugInfo.correctedImage = correctedImage;

      if (debugInfo.compareWith != null) {
        final errorImg = Image(
            height: decolorized.height * 2,
            width: decolorized.width * 2,
            backgroundColor: ColorRgb8(255, 255, 255));

        for (int x = 0; x < decolorized.width; x++) {
          for (int y = 0; y < decolorized.height; y++) {
            if (decolorized[x][y] != debugInfo.compareWith!.data[x][y]) {
              debugInfo.errorCount++;
              errorImg.setPixel(
                  x * 2,
                  y * 2,
                  Compression.defaultPalette[compressionLevel]
                      [decolorized[x][y]]);
              errorImg.setPixel(
                  x * 2 + 1,
                  y * 2 + 1,
                  Compression.defaultPalette[compressionLevel]
                      [debugInfo.compareWith!.data[x][y]]);
            }
          }
        }
      }
    }

    return decodeMatrix(decolorized, Compression(level: compressionLevel));
  }

  DecoderResult decodeMatrix(ByteMatrix bits, Compression compression) {
    final parser = BitMatrixParser(bits);
    parser.compression = compression;
    FormatsException? fe;
    ChecksumException? ce;
    try {
      return _decodeParser(parser, compression);
    } on FormatsException catch (e) {
      fe = e;
    } on ChecksumException catch (e) {
      ce = e;
    }

    try {
      // Revert the bit matrix
      parser.remask();

      // Will be attempting a mirrored reading of the version and format info.
      parser.setMirror(true);

      // Preemptively read the version.
      parser.readVersion();

      // Preemptively read the format information.
      parser.readFormatInformation();

      /*
       * Since we're here, this means we have successfully detected some kind
       * of version and format information when mirrored. This is a good sign,
       * that the QR code may be mirrored, and we should try once more with a
       * mirrored content.
       */
      // Prepare for a mirrored reading.
      parser.mirror();

      final result = _decodeParser(parser, compression);

      // Success! Notify the caller that the code was mirrored.

      return result;
    } on ChecksumException catch (_) {
      // Throw the exception from the original reading
      if (fe != null) {
        throw fe;
      }
      throw ce!; // If fe is null, this can't be
    } on FormatsException catch (_) {
      // Throw the exception from the original reading
      if (fe != null) {
        throw fe;
      }
      throw ce!; // If fe is null, this can't be
    }
  }

  DecoderResult _decodeParser(BitMatrixParser parser, Compression compression) {
    final version = parser.readVersion();
    final ecLevel = parser.readFormatInformation().errorCorrection;

    // Read codewords
    final codewords = parser.readCodewords();
    final data = codewords.data;
    final blocks = <DecBlockPair>[];
    final ecbGroup = version.ecbGroup;
    var maxDataByteCount = 0;

    for (final ecb in ecbGroup.ecBlocks) {
      final dSize = ecb.dCodewordsPerBlock;
      if (maxDataByteCount < dSize) maxDataByteCount = dSize;

      for (int i = 0; i < ecb.repeatCount; i++) {
        blocks.add(
          DecBlockPair(
            Uint8List(dSize),
            Uint8List(ecbGroup.ecCodewordsPerBlock),
          ),
        );
      }
    }

    var index = 0;

    // First, place data blocks.
    for (int i = 0; i < maxDataByteCount; i++) {
      for (final block in blocks) {
        final dataBytes = block.dataCodewords;
        if (i < dataBytes.length) {
          dataBytes[i] = data[index++];
        }
      }
    }

    // Then, place error correction blocks.
    for (int i = 0; i < ecbGroup.ecCodewordsPerBlock; i++) {
      for (final block in blocks) {
        block.errorCorrectionCodewords[i] = data[index++];
      }
    }

    final dataBytes = Uint8List(ecbGroup.dCodewordCount);
    var dataBytesOffset = 0;
    var errorsCorrected = 0;

    for (final block in blocks) {
      errorsCorrected += _correctErrors(block);
      dataBytes.setAll(dataBytesOffset, block.dataCodewords);
      dataBytesOffset += block.dCodewordCount;
    }

    final resultBytes = BitWriter.from(dataBytes);

    return DecodedBitStreamParser.decode(
        resultBytes.reader, version, ecLevel, compression)
      ..errorsCorrected = errorsCorrected;
  }

  /// Given data and error-correction codewords received,
  /// possibly corrupted by errors, attempts to
  /// correct the errors in-place using Reed-Solomon error correction.
  int _correctErrors(DecBlockPair blockPair) {
    final decBytes = blockPair.dataCodewords
        .followedBy(blockPair.errorCorrectionCodewords)
        .toList();
    int errorsCorrected = 0;
    try {
      errorsCorrected = _rsDecoder.decodeWithEcCount(
        decBytes,
        blockPair.ecCodewordCount,
      );
    } on ReedSolomonException catch (_) {
      throw ChecksumException();
    }
    // Copy back into array of bytes -- only need to worry about the bytes that were data
    // We don't care about errors in the error-correction codewords
    for (int i = 0; i < blockPair.dCodewordCount; i++) {
      blockPair.dataCodewords[i] = decBytes[i];
    }

    return errorsCorrected;
  }
}

class HueSamplesRange {
  int start;
  int end;
  List<int> hs;
  List<int> ls;
  List<int> lsSmooth = [];
  int lThreshold = 0;

  HueSamplesRange(this.start, this.end,
      [this.hs = const [], this.ls = const []]);
}
