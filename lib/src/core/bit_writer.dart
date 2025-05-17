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

import '../core/bit_reader.dart';

class BitWriter {
  Uint8List _data;
  int _position = 0;

  BitWriter({int capacity = 32}) : _data = Uint8List((capacity + 7) ~/ 8);

  BitWriter.copy(BitWriter other)
      : _data = Uint8List.fromList(other._data),
        _position = other._position;

  // TODO: remove this constructor
  BitWriter.from(Uint8List data, {int? length})
      : _data = data,
        _position = length ?? data.lengthInBytes * 8;

  // TODO: make it read-only
  /// The data represented as a byte array.
  Uint8List get data => Uint8List.view(_data.buffer, 0, lengthInBytes);
  int get length => _position;
  int get lengthInBytes => (_position + 7) ~/ 8;
  BitReader get reader => BitReader(this);

  void add(bool value) {
    _ensureCapacity(1);

    if (value) {
      _data[_position ~/ 8] |= 1 << (7 - _position % 8);
    }

    _position++;
  }

  void addInt(int value, int bitCount) {
    RangeError.checkValueInInterval(bitCount, 0, 32, 'bitCount');
    _ensureCapacity(bitCount);
    value &= (1 << bitCount) - 1;

    final freeBitCount = 8 - _position % 8;
    var index = _position ~/ 8;

    if (freeBitCount >= bitCount) {
      _data[index] |= value << (freeBitCount - bitCount);
    } else {
      var remaining = bitCount - freeBitCount;
      _data[index++] |= value >> remaining;

      while (remaining > 8) {
        remaining -= 8;
        _data[index++] = value >> remaining;
      }

      _data[index] |= value << (8 - remaining);
    }

    _position += bitCount;
  }

  void addOther(BitReader other) {
    final bitCount = other.length;

    final dataLength = (bitCount + 7) ~/ 8;
    var bitCountInLast = bitCount % 8;
    if (bitCountInLast == 0) bitCountInLast = 8;

    _ensureCapacity(bitCount);

    for (var i = 0; i < dataLength - 1; i++) {
      addInt(other.data[i], 8);
    }

    if (bitCountInLast > 0) {
      addInt(
        other.data[dataLength - 1] >> (8 - bitCountInLast),
        bitCountInLast,
      );
    }
  }

  void _ensureCapacity(int bitCount) {
    final newDataLength = (_position + bitCount + 7) ~/ 8;
    if (_data.length >= newDataLength) return;
    final newData = Uint8List(newDataLength * 2);
    newData.setRange(0, _data.length, _data);
    _data = newData;
  }
}
