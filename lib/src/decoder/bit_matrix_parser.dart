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

import '../core/bit_reader.dart';
import '../core/bit_writer.dart';
import '../core/byte_matrix.dart';
import '../core/compression.dart';
import '../core/format_information.dart';
import '../core/matrix_builder.dart';
import '../core/version.dart';
import '../exceptions/formats_exception.dart';

/// @author Sean Owen
class BitMatrixParser {
  final ByteMatrix _bitMatrix;
  Version? _parsedVersion;
  FormatInformation? _parsedFormatInfo;
  bool _isMirror = false;

  /// @param bitMatrix [BitMatrix] to parse
  /// @throws FormatException if dimension is not >= 21 and 1 mod 4
  BitMatrixParser(this._bitMatrix) {
    final dimension = _bitMatrix.height;
    if (dimension < 21 || (dimension & 0x03) != 1) {
      throw FormatsException.instance;
    }
  }

  /// <p>Reads format information from one of its two locations within the QR Code.</p>
  ///
  /// @return [FormatInformation] encapsulating the QR Code's format info
  /// @throws FormatException if both format information locations cannot be parsed as
  /// the valid encoding of format information
  FormatInformation readFormatInformation() {
    // Read top-left format information bits
    int formatInfoBits1 = 0;
    for (int i = 0; i < 6; i++) {
      formatInfoBits1 = _copyBit(i, 8, formatInfoBits1);
    }
    // .. and skip a bit in the timing pattern ...
    formatInfoBits1 = _copyBit(7, 8, formatInfoBits1);
    formatInfoBits1 = _copyBit(8, 8, formatInfoBits1);
    formatInfoBits1 = _copyBit(8, 7, formatInfoBits1);
    // .. and skip a bit in the timing pattern ...
    for (int j = 5; j >= 0; j--) {
      formatInfoBits1 = _copyBit(8, j, formatInfoBits1);
    }

    _parsedFormatInfo = FormatInformation.tryDecode(formatInfoBits1);
    if (_parsedFormatInfo != null) return _parsedFormatInfo!;

    // Read the top-right/bottom-left pattern too
    final dimension = _bitMatrix.height;
    int formatInfoBits2 = 0;
    final jMin = dimension - 7;
    for (int j = dimension - 1; j >= jMin; j--) {
      formatInfoBits2 = _copyBit(8, j, formatInfoBits2);
    }
    for (int i = dimension - 8; i < dimension; i++) {
      formatInfoBits2 = _copyBit(i, 8, formatInfoBits2);
    }

    _parsedFormatInfo = FormatInformation.tryDecode(formatInfoBits2);
    if (_parsedFormatInfo != null) return _parsedFormatInfo!;

    // According to ZXing implementation some QR codes may not mask the format
    //information, so we should try to bring the matter to an end
    final fiMask = FormatInformation.maskBits;
    _parsedFormatInfo = FormatInformation.tryDecode(formatInfoBits1 ^ fiMask) ??
        FormatInformation.tryDecode(formatInfoBits2 ^ fiMask);
    if (_parsedFormatInfo != null) return _parsedFormatInfo!;

    throw FormatsException.instance;
  }

  /// <p>Reads version information from one of its two locations within the QR Code.</p>
  ///
  /// @return [Version] encapsulating the QR Code's version
  /// @throws FormatException if both version information locations cannot be parsed as
  /// the valid encoding of version information
  Version readVersion() {
    final dimension = _bitMatrix.height;

    final provisionalVersion = (dimension - 17) ~/ 4;
    if (provisionalVersion < 7) {
      return Version(
        number: provisionalVersion,
        compression: compression,
        errorCorrection:
            (_parsedFormatInfo ?? readFormatInformation()).errorCorrection,
      );
    }

    // Read top-right version info: 3 wide by 6 tall
    int versionBits = 0;
    final ijMin = dimension - 11;
    for (int j = 5; j >= 0; j--) {
      for (int i = dimension - 9; i >= ijMin; i--) {
        versionBits = _copyBit(i, j, versionBits);
      }
    }

    var parsedVersionNumber = Version.tryDecodeNumber(versionBits);
    if (parsedVersionNumber != null) {
      _parsedVersion = Version(
        number: parsedVersionNumber,
        compression: compression,
        errorCorrection:
            (_parsedFormatInfo ?? readFormatInformation()).errorCorrection,
      );
    }
    if (_parsedVersion!.dimension == dimension) {
      return _parsedVersion!;
    }

    // Hmm, failed. Try bottom left: 6 wide by 3 tall
    versionBits = 0;
    for (int i = 5; i >= 0; i--) {
      for (int j = dimension - 9; j >= ijMin; j--) {
        versionBits = _copyBit(i, j, versionBits);
      }
    }

    parsedVersionNumber = Version.tryDecodeNumber(versionBits);
    if (parsedVersionNumber != null) {
      _parsedVersion = Version(
        number: parsedVersionNumber,
        compression: compression,
        errorCorrection: _parsedFormatInfo!.errorCorrection,
      );
    }
    if (_parsedVersion!.dimension == dimension) {
      return _parsedVersion!;
    }

    throw FormatsException.instance;
  }

  int _copyBit(int i, int j, int versionBits) {
    final bit = (_isMirror ? _bitMatrix[j][i] : _bitMatrix[i][j]) != 0;
    return bit ? (versionBits << 1) | 0x1 : versionBits << 1;
  }

  late Compression compression;

  /// <p>Reads the bits in the [BitMatrix] representing the finder pattern in the
  /// correct order in order to reconstruct the codewords bytes contained within the
  /// QR Code.</p>
  ///
  /// @return bytes encoded within the QR Code
  /// @throws FormatException if the exact number of bytes expected is not read
  BitReader readCodewords() {
    final formatInfo = _parsedFormatInfo ?? readFormatInformation();
    final version = _parsedVersion ?? readVersion();

    // Get the data mask for the format used in this QR Code. This will exclude
    // some bits from reading as we wind through the bit matrix.
    final dataMask = formatInfo.mask;
    final dimension = _bitMatrix.height;

    final isMasked = dataMask.isMasked;
    for (int x = 0; x < dimension; x++) {
      for (int y = 0; y < dimension; y++) {
        if (isMasked(x, y)) {
          _bitMatrix[x][y] = ~_bitMatrix[x][y] & compression.bitMask;
        }
      }
    }

    final builder = MatrixBuilder(version: version)..buildDummyMatrix();
    final functionPattern = builder.matrix;
    // for (int y = 0; y < functionPattern.height; y++) {
    //   var string = '';
    //   for (int x = 0; x < functionPattern.width; x++) {
    //     string += functionPattern[x][y].toString();
    //   }
    //   print(string);
    // }

    bool readingUp = true;
    final byteCount = version.codewordCount;
    final bitCount = byteCount * 8;
    final result =
        //Uint8List(version.totalCodewords * compression.bitsPerModule);
        //Uint8List(byteCount);
        BitWriter(capacity: bitCount);
    // int resultOffset = 0;
    // int currentByte = 0;
    // int bitsRead = 0;
    // Read columns in pairs, from right to left
    damnThereAreLabels:
    for (int j = dimension - 1; j > 0; j -= 2) {
      if (j == 6) {
        // Skip whole column with vertical alignment pattern;
        // saves time and makes the other code proceed more cleanly
        j--;
      }
      // Read alternatingly from bottom to top then top to bottom
      for (int count = 0; count < dimension; count++) {
        final i = readingUp ? dimension - 1 - count : count;
        for (int col = 0; col < 2; col++) {
          // Ignore bits covered by the function pattern
          if (!(functionPattern[j - col][i] == MatrixBuilder.noModule)) {
            // Read a bit
            //TODO: check if this is correct
            int value = _bitMatrix[j - col][i];

            result.addInt(value, compression.bitsPerModule);

            if (result.length >= bitCount) {
              break damnThereAreLabels;
            }

            // for (int k = compression.bitsPerModule; k > 0; k--) {
            //   bitsRead++;
            //   currentByte <<= 1;

            //   currentByte |= (value >> (k - 1)) & 1;

            //   // If we've made a whole byte, save it off
            //   if (bitsRead == 8) {
            //     result[resultOffset++] = currentByte;
            //     bitsRead = 0;
            //     currentByte = 0;
            //   }

            //   if (resultOffset == byteCount) {
            //     break damnThereAreLabels;
            //   }
            // }
          }
        }
      }
      readingUp ^= true; // readingUp = !readingUp; // switch directions
    }
    // if (resultOffset != byteCount) {
    //   throw FormatsException.instance;
    // }
    return result.reader;
  }

  /// Revert the mask removal done while reading the code words. The bit matrix should revert to its original state.
  void remask() {
    if (_parsedFormatInfo == null) {
      return; // We have no format information, and have no data mask
    }
    final dataMask = _parsedFormatInfo!.mask;
    final dimension = _bitMatrix.height;

    final isMasked = dataMask.isMasked;
    for (int x = 0; x < dimension; x++) {
      for (int y = 0; y < dimension; y++) {
        if (isMasked(x, y)) {
          _bitMatrix[x][y] = ~_bitMatrix[x][y] & compression.bitMask;
        }
      }
    }
  }

  /// Prepare the parser for a mirrored operation.
  /// This flag has effect only on the {@link #readFormatInformation()} and the
  /// {link #readVersion()}. Before proceeding with {@link #readCodewords()} the
  /// {link #mirror()} method should be called.
  ///
  /// @param mirror Whether to read version and format information mirrored.
  void setMirror(bool mirror) {
    _parsedVersion = null;
    _parsedFormatInfo = null;
    _isMirror = mirror;
  }

  /// Mirror the bit matrix in order to attempt a second reading.
  void mirror() {
    for (int x = 0; x < _bitMatrix.width; x++) {
      for (int y = x + 1; y < _bitMatrix.height; y++) {
        final v1 = _bitMatrix[x][y];
        final v2 = _bitMatrix[y][x];
        _bitMatrix[x][y] = v2;
        _bitMatrix[y][x] = v1;
      }
    }
  }
}
