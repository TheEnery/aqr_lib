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

import 'package:aqr_lib/src/core/mode.dart';
import 'package:aqr_lib/src/core/version.dart';

class Segment {
  String content;
  Mode mode;

  Segment({required this.content, required this.mode});

  int get characterCount => content.length;

  /// Returns length in bits. See ISO 18004:2015, 7.4.3 - 7.4.6
  int calculateLength(Version version) {
    // Mode indicator length.
    final M = 4;
    // Number of bits in character count indicator.
    final C = mode.getCharacterCountBitLength(version);
    // Number of input data characters.
    final D = characterCount;

    switch (mode) {
      case Mode.numeric:
        return M + C + 10 * (D ~/ 3) + (const [0, 4, 7])[D % 3];
      case Mode.alphanumeric:
        return M + C + 11 * (D ~/ 2) + 6 * (D % 2);
      case Mode.byte:
        // TODO: remove this workaround
        return M + C + 8 * D /* String character needs 2 byte */ * 2;
      case Mode.kanji:
        return M + C + 13 * D;
      default:
        throw StateError('${mode.bits} mode cannot be used in a segment');
    }
  }
}
