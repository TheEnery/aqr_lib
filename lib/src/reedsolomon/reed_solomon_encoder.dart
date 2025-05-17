/*
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

import 'generic_gf.dart';
import 'generic_gfpoly.dart';

/// Implements Reed-Solomon encoding, as the name implies.
///
/// @author Sean Owen
/// @author William Rucklidge
class ReedSolomonEncoder {
  final GenericGF _field;
  final List<GenericGFPoly> _cachedGenerators;

  ReedSolomonEncoder(this._field) : _cachedGenerators = [] {
    _cachedGenerators.add(GenericGFPoly(_field, Int32List.fromList([1])));
  }

  List<int> encode(List<int> dataBytes, int ecByteCount) {
    final dByteCount = dataBytes.length;

    if (ecByteCount <= 0) {
      throw ArgumentError('Error correction byte count must be greater than 0');
    }
    if (dByteCount <= 0) {
      throw ArgumentError('No data bytes provided');
    }

    final generator = _buildGenerator(ecByteCount);

    GenericGFPoly info = GenericGFPoly(_field, dataBytes);
    info = info.multiplyByMonomial(ecByteCount, 1);
    final remainder = info.divide(generator)[1];
    final coefficients = remainder.coefficients;
    final zeroCoefficientCount = ecByteCount - coefficients.length;

    coefficients.insertAll(
      0,
      Iterable.generate(zeroCoefficientCount, (_) => 0),
    );

    return coefficients;
  }

  GenericGFPoly _buildGenerator(int degree) {
    if (degree >= _cachedGenerators.length) {
      GenericGFPoly lastGenerator =
          _cachedGenerators[_cachedGenerators.length - 1];
      for (int d = _cachedGenerators.length; d <= degree; d++) {
        final nextGenerator = lastGenerator.multiply(
          GenericGFPoly(
            _field,
            Int32List.fromList([1, _field.exp(d - 1 + _field.generatorBase)]),
          ),
        );
        _cachedGenerators.add(nextGenerator);
        lastGenerator = nextGenerator;
      }
    }
    return _cachedGenerators[degree];
  }
}
