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

import 'dart:typed_data';

import '../core/bit_writer.dart';

class BitReader {
  final BitWriter writer;
  int _position = 0;

  BitReader(this.writer);

  int get available => writer.length - _position;
  Uint8List get data => writer.data;
  int get length => writer.length;
  int get lengthInBytes => writer.lengthInBytes;

  bool operator [](int index) {
    final value = data[index ~/ 8];
    final bit = (value >> (7 - index % 8)) & 1;

    return bit == 1;
  }

  bool get() {
    _checkAvailable(1);

    final value = data[_position ~/ 8];
    final bit = (value >> (7 - _position % 8)) & 1;

    _position++;

    return bit == 1;
  }

  int getInt(int bitCount) {
    RangeError.checkValueInInterval(bitCount, 0, 32, 'bitCount');
    _checkAvailable(bitCount);
    var value = 0;

    final freeBitCount = 8 - _position % 8;
    var index = _position ~/ 8;

    if (freeBitCount >= bitCount) {
      value =
          (data[index] >> (freeBitCount - bitCount)) & ((1 << bitCount) - 1);
    } else {
      var remaining = bitCount - freeBitCount;
      value = (data[index++] & ((1 << freeBitCount) - 1)) << remaining;

      while (remaining > 8) {
        remaining -= 8;
        value |= data[index++] << remaining;
      }

      value |= data[index] >> (8 - remaining);
    }

    _position += bitCount;
    return value;
  }

  void _checkAvailable(int bitCount) {
    if (_position + bitCount > length) {
      throw RangeError('Not enough bits available');
    }
  }
}
