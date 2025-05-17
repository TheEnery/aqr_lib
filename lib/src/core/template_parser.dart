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

import 'dart:convert';

import 'template.dart';

abstract class TemplateParser<T extends Template> {
  const TemplateParser();
  T? parse(String rawText);

  String unescapeBackslash(String escaped) {
    final backslash = escaped.indexOf('\\');
    if (backslash < 0) {
      return escaped;
    }
    final max = escaped.length;
    final unescaped = StringBuffer();
    unescaped.write(escaped.substring(0, backslash));
    bool nextIsEscaped = false;
    for (int i = backslash; i < max; i++) {
      final c = escaped[i];
      if (nextIsEscaped || c != '\\') {
        unescaped.write(c);
        nextIsEscaped = false;
      } else {
        nextIsEscaped = true;
      }
    }
    return unescaped.toString();
  }

  static int parseHexDigit(String chr) {
    final c = chr.codeUnitAt(0);
    if (c >= 48 /*'0'*/ && c <= 57 /*'9'*/) {
      return c - 48;
    }
    if (c >= 97 /*'a'*/ && c <= 102 /*'f'*/) {
      return 10 + (c - 97);
    }
    if (c >= 65 /*'A'*/ && c <= 70 /*'F'*/) {
      return 10 + (c - 65);
    }
    return -1;
  }

  Map<String, String>? parseNameValuePairs(String uri) {
    final paramStart = uri.indexOf('?');
    if (paramStart < 0) {
      return null;
    }
    final result = <String, String>{};
    for (String keyValue in uri.substring(paramStart + 1).split('&')) {
      _appendKeyValue(keyValue, result);
    }
    return result;
  }

  void _appendKeyValue(String keyValue, Map<String, String> result) {
    final keyValueTokens = keyValue.split('='); // todo 2
    if (keyValueTokens.length == 2) {
      final key = keyValueTokens[0];
      String value = keyValueTokens[1];
      try {
        value = urlDecode(value);
        result[key] = value;
      } catch (_) {
        // IllegalArgumentException
        // continue; invalid data such as an escape like %0t
      }
    }
  }

  String urlDecode(String encoded) {
    try {
      //todo decodeFull or decodeComponent or decodeQueryComponent ?
      return Uri.decodeQueryComponent(encoded, encoding: utf8);
    } catch (_) {
      // UnsupportedEncodingException
      rethrow; // can't happen
    }
  }

  List<String>? matchPrefixedField(
    String prefix,
    String rawText,
    String endChar,
    bool trim,
  ) {
    List<String>? matches;
    int i = 0;
    final int max = rawText.length;
    while (i < max) {
      i = rawText.indexOf(prefix, i);
      if (i < 0) {
        break;
      }
      i += prefix.length; // Skip past this prefix we found to start
      final int start = i; // Found the start of a match here
      bool more = true;
      while (more) {
        i = rawText.indexOf(endChar, i);
        if (i < 0) {
          // No terminating end character? uh, done. Set i such that loop terminates and break
          i = rawText.length;
          more = false;
        } else if (_countPrecedingBackslashes(rawText, i) % 2 != 0) {
          // semicolon was escaped (odd count of preceding backslashes) so continue
          i++;
        } else {
          // found a match
          matches ??= [];
          String element = unescapeBackslash(rawText.substring(start, i));
          if (trim) {
            element = element.trim();
          }
          if (element.isNotEmpty) {
            matches.add(element);
          }
          i++;
          more = false;
        }
      }
    }
    if (matches == null || matches.isEmpty) {
      return null;
    }
    return matches.toList();
  }

  int _countPrecedingBackslashes(String s, int pos) {
    int count = 0;
    for (int i = pos - 1; i >= 0; i--) {
      if (s[i] == '\\') {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  String? matchSinglePrefixedField(
    String prefix,
    String rawText,
    String endChar,
    bool trim,
  ) {
    final List<String>? matches =
        matchPrefixedField(prefix, rawText, endChar, trim);
    return matches == null ? null : matches[0];
  }
}
