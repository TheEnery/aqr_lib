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

import '../core/template.dart';

class UrlTemplate extends Template {
  String url;
  String? title;

  UrlTemplate(String url, [this.title]) : url = _massageURL(url);

  @override
  String get displayResult {
    final result = StringBuffer();
    maybeAppend(title, result);
    maybeAppend(url, result);
    return result.toString();
  }

  // @override
  // Widget display() {
  //   return Text(
  //     displayResult,
  //     style: const TextStyle(
  //       fontSize: 16,
  //       color: Colors.blue,
  //       decoration: TextDecoration.underline,
  //     ),
  //   );
  // }

  /// Transforms a string that represents a URI into something more proper, by adding or canonicalizing
  /// the protocol.
  static String _massageURL(String url) {
    url = url.trim();
    final protocolEnd = url.indexOf(':');
    if (protocolEnd < 0 || _isColonFollowedByPortNumber(url, protocolEnd)) {
      // No protocol, or found a colon, but it looks like it is after the host, so the protocol is still missing,
      // so assume http
      url = 'http://$url';
    }
    return url;
  }

  static bool _isColonFollowedByPortNumber(String url, int protocolEnd) {
    final start = protocolEnd + 1;
    int nextSlash = url.indexOf('/', start);
    if (nextSlash < 0) {
      nextSlash = url.length;
    }
    return _isSubstringOfDigits(url, start, nextSlash - start);
  }

  static bool _isSubstringOfDigits(String? value, int offset, int length) {
    if (value == null || length <= 0) {
      return false;
    }
    final max = offset + length;
    return value.length >= max &&
        _digits.hasMatch(value.substring(offset, max));
  }

  static final _digits = RegExp(r'^\d+$');
}
