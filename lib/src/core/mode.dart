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

import 'version.dart';

/// See ISO 18004:2006, 6.4.1, Tables 2 and 3. This enum encapsulates the various modes in which
/// data can be encoded to bits in the QR code standard.
///
/// @author Sean Owen
class Mode {
  static const terminator = Mode._([0, 0, 0], 0x0);
  static const numeric = Mode._([10, 12, 14], 0x1);
  static const alphanumeric = Mode._([9, 11, 13], 0x2);
  // Not supported
  static const structuredAppend = Mode._([0, 0, 0], 0x3);
  static const byte = Mode._([8, 16, 16], 0x4);
  static const fnc1FirstPosition = Mode._([0, 0, 0], 0x5);
  static const eci = Mode._([0, 0, 0], 0x7);
  static const kanji = Mode._([8, 10, 12], 0x8);
  static const fnc1SecondPosition = Mode._([0, 0, 0], 0x9);

  /// See GBT 18284-2000; "Hanzi" is a transliteration of this mode name.
  static const hanzi = Mode._([8, 10, 12], 0xD);

  final List<int> _characterCountBitsLookup;
  final int bits;

  const Mode._(this._characterCountBitsLookup, this.bits);

  factory Mode.fromBits(int bits) {
    RangeError.checkValueInInterval(bits, 0x0, 0xF);
    final mode = _values[bits];
    return mode ?? (throw UnsupportedError('Unsupported mode $bits'));
  }

  int getCharacterCountBitLength(Version version) {
    int offset;
    if (version.number <= 9) {
      offset = 0;
    } else if (version.number <= 26) {
      offset = 1;
    } else {
      offset = 2;
    }

    final bpm = version.compression.bitsPerModule;
    if (bpm != 1) {
      if (this == byte) {
        return 16;
      }

      if (bpm.isEven) {
        return _characterCountBitsLookup[offset] + bpm ~/ 2;
      } else {
        return _characterCountBitsLookup[offset] + (bpm + 1) ~/ 2;
      }
    }

    return _characterCountBitsLookup[offset];
  }

  static const _values = [
    terminator,
    numeric,
    alphanumeric,
    structuredAppend,
    byte,
    fnc1FirstPosition,
    null,
    eci,
    kanji,
    fnc1SecondPosition,
    null,
    null,
    null,
    hanzi,
    null,
    null,
  ];
}
