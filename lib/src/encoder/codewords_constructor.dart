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

import 'dart:convert';
import 'dart:typed_data';

import 'package:aqr_lib/src/encoder/segment.dart';

import '../core/bit_writer.dart';
import '../core/mode.dart';
import '../core/string_utils.dart';
import '../core/version.dart';
import '../exceptions/writer_exception.dart';

class CodewordsConstructor {
  final List<Segment> _segments;

  CodewordsConstructor() : _segments = <Segment>[];
  CodewordsConstructor.fromSegments(this._segments);

  void addContent(String content) {
    _segments.add(Segment(content: content, mode: chooseMode(content)));
  }

  int calculateDataSize(Version version) {
    return _segments.fold(
      0,
      (size, segment) => size += segment.calculateLength(version),
    );
  }

  Uint8List makeCodewords(Version version) {
    final writer = BitWriter();

    for (final segment in _segments) {
      addMode(segment.mode, writer);
      addCharacterCount(
        segment.characterCount,
        segment.mode,
        version,
        writer,
      );
      add(segment.content, segment.mode, writer);
    }

    terminate(version, writer);

    return writer.data;
  }

  //////////////////////////////////////////////////////////////////////////////

  /// Adds [content] into [bits] using [mode] mode.
  void add(
    String content,
    Mode mode,
    BitWriter bits, [
    Encoding encoding = utf8,
  ]) {
    switch (mode) {
      case Mode.numeric:
        addNumeric(content, bits);
        break;
      case Mode.alphanumeric:
        addAlphanumeric(content, bits);
        break;
      case Mode.byte:
        addBytes(content, bits, encoding);
        break;
      case Mode.kanji:
        addKanji(content, bits);
        break;
      default:
        throw WriterException('Invalid mode: $mode');
    }
  }

  void addAlphanumeric(String content, BitWriter bits) {
    final length = content.length;
    int i = 0;
    while (i < length) {
      final code1 = StringUtils.getAlphanumericCode(content.codeUnitAt(i));
      if (code1 == -1) {
        throw WriterException();
      }
      if (i + 1 < length) {
        final code2 =
            StringUtils.getAlphanumericCode(content.codeUnitAt(i + 1));
        if (code2 == -1) {
          throw WriterException();
        }
        // Encode two alphanumeric letters in 11 bits.
        bits.addInt(code1 * 45 + code2, 11);
        i += 2;
      } else {
        // Encode one alphanumeric letter in six bits.
        bits.addInt(code1, 6);
        i++;
      }
    }
  }

  void addBytes(String content, BitWriter bits, Encoding encoding) {
    final bytes = encoding.encode(content);
    for (int b in bytes) {
      bits.addInt(b, 8);
    }
  }

  void addCharacterCount(
    int characterCount,
    Mode mode,
    Version version,
    BitWriter bits,
  ) {
    final bitCount = mode.getCharacterCountBitLength(version);

    if (characterCount >= (1 << bitCount)) {
      throw StateError(
        '$characterCount character count cannot fit into $bitCount bits',
      );
    }

    bits.addInt(characterCount, bitCount);
  }

  void addKanji(String content, BitWriter bits) {
    final bytes = StringUtils.shiftJisCharset.encode(content);

    if (bytes.length.isOdd) {
      throw StateError('Kanji byte size not even');
    }

    final maxI = bytes.length - 1;
    for (int i = 0; i < maxI; i += 2) {
      final byte1 = bytes[i] & 0xFF;
      final byte2 = bytes[i + 1] & 0xFF;
      final code = ((byte1 << 8) & 0xFFFFFFFF) | byte2;
      int subtracted = -1;

      if (code >= 0x8140 && code <= 0x9FFC) {
        subtracted = code - 0x8140;
      } else if (code >= 0xE040 && code <= 0xEBBF) {
        subtracted = code - 0xC140;
      }

      if (subtracted == -1) {
        throw StateError('Invalid byte sequence');
      }

      final encoded = ((subtracted >> 8) * 0xC0) + (subtracted & 0xFF);
      bits.addInt(encoded, 13);
    }
  }

  void addMode(Mode mode, BitWriter bits) {
    bits.addInt(mode.bits, 4);
  }

  void addNumeric(String content, BitWriter bits) {
    final length = content.length;
    int i = 0;
    while (i < length) {
      final num1 = content.codeUnitAt(i) - 48 /* 0 */;
      if (i + 2 < length) {
        // Encode three numeric letters in ten bits.
        final num2 = content.codeUnitAt(i + 1) - 48 /* 0 */;
        final num3 = content.codeUnitAt(i + 2) - 48 /* 0 */;
        bits.addInt(num1 * 100 + num2 * 10 + num3, 10);
        i += 3;
      } else if (i + 1 < length) {
        // Encode two numeric letters in seven bits.
        final num2 = content.codeUnitAt(i + 1) - 48 /* 0 */;
        bits.addInt(num1 * 10 + num2, 7);
        i += 2;
      } else {
        // Encode one numeric letter in four bits.
        bits.addInt(num1, 4);
        i++;
      }
    }
  }

  /// Choose the best mode by examining the content.
  Mode chooseMode(String content, [Encoding? encoding]) {
    if (StringUtils.shiftJisCharset == encoding &&
        StringUtils.isOnlyDoubleByteKanji(content)) {
      // Choose Kanji mode if all input are double-byte characters
      return Mode.kanji;
    }
    bool hasNumeric = false;
    bool hasAlphanumeric = false;
    for (int i = 0; i < content.length; ++i) {
      final c = content.codeUnitAt(i);
      if (c >= 48 /* 0 */ && c <= 57 /* 9 */) {
        hasNumeric = true;
      } else if (StringUtils.getAlphanumericCode(c) != -1) {
        hasAlphanumeric = true;
      } else {
        return Mode.byte;
      }
    }
    if (hasAlphanumeric) {
      return Mode.alphanumeric;
    }
    if (hasNumeric) {
      return Mode.numeric;
    }
    return Mode.byte;
  }

  /// Terminate bits as described in 8.4.8 and 8.4.9 of JISX0510:2004 (p.24).
  void terminate(Version version, BitWriter bits) {
    final dByteCount = version.ecbGroup.dCodewordCount;
    final capacity = dByteCount * 8;
    final available = capacity - bits.length;

    // Add Mode.terminate if there is enough space (value is 0000).
    final terminateModeBitCount = available < 4 ? available : 4;
    bits.addInt(0x0, terminateModeBitCount);

    // Align to byte. See 8.4.8 of JISX0510:2004 (p.24) for details.
    final toByteAlignmentBitCount = (8 - (bits.length & 0x7)) & 0x7;
    bits.addInt(0x0, toByteAlignmentBitCount);

    // Fill the remaining space with padding patterns defined in 8.4.9 (p.24).
    final paddingByteCount = dByteCount - bits.lengthInBytes;
    for (int i = 0; i < paddingByteCount; i++) {
      bits.addInt((i & 0x1) == 0 ? 0xEC : 0x11, 8);
    }
  }
}
