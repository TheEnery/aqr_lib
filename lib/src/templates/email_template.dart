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

/// Represents a parsed result that encodes an email message including recipients, subject
/// and body text.
///
/// @author Sean Owen
class EmailTemplate extends Template {
  List<String>? _tos;
  List<String>? _ccs;
  List<String>? _bccs;
  String? subject;
  String? body;

  EmailTemplate(
    dynamic tos, [
    this._ccs,
    this._bccs,
    this.subject,
    this.body,
  ]) : _tos = tos is String ? [tos] : tos as List<String>?;

  List<String>? get tos => _tos;

  List<String>? get ccs => _ccs;

  List<String>? get bccs => _bccs;

  void addTo(String to) {
    _tos ??= [];
    _tos!.add(to);
  }

  void addCC(String to) {
    _ccs ??= [];
    _ccs!.add(to);
  }

  void addBCC(String to) {
    _bccs ??= [];
    _bccs!.add(to);
  }

  @override
  String get displayResult {
    final result = StringBuffer();
    maybeAppendList(_tos, result);
    maybeAppendList(_ccs, result);
    maybeAppendList(_bccs, result);
    maybeAppend(subject, result);
    maybeAppend(body, result);
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
}
