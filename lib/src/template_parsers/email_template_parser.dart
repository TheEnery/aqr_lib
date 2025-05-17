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

import '../templates/email_template.dart';
import '../core/template_parser.dart';

/// Represents a result that encodes an e-mail address.
///
/// either as a plain address like "joe@example.org"
/// or a mailto: URL like "mailto:joe@example.org".
///
/// @author Sean Owen
class EmailTemplateParser extends TemplateParser<EmailTemplate> {
  const EmailTemplateParser();

  @override
  EmailTemplate? parse(String rawText) {
    if (rawText.startsWith('mailto:') || rawText.startsWith('MAILTO:')) {
      // If it starts with mailto:, assume it is definitely trying to be an email address
      String hostEmail = rawText.substring(7);
      final queryStart = hostEmail.indexOf('?');
      if (queryStart >= 0) {
        hostEmail = hostEmail.substring(0, queryStart);
      }
      try {
        hostEmail = urlDecode(hostEmail);
      } catch (_) {
        // IllegalArgumentException
        return null;
      }
      List<String>? tos;
      if (hostEmail.isNotEmpty) {
        tos = hostEmail.split(',');
      }
      final nameValues = parseNameValuePairs(rawText);
      List<String>? ccs;
      List<String>? bccs;
      String? subject;
      String? body;
      if (nameValues != null) {
        if (tos == null) {
          final tosString = nameValues['to'];
          if (tosString != null) {
            tos = tosString.split(',');
          }
        }
        final ccString = nameValues['cc'];
        if (ccString != null) {
          ccs = ccString.split(',');
        }
        final bccString = nameValues['bcc'];
        if (bccString != null) {
          bccs = bccString.split(',');
        }
        subject = nameValues['subject'];
        body = nameValues['body'];
      }
      return EmailTemplate(tos, ccs, bccs, subject, body);
    } else {
      if (!isBasicallyValidEmailAddress(rawText)) {
        return null;
      }
      return EmailTemplate(rawText);
    }
  }

  bool isBasicallyValidEmailAddress(String? email) =>
      email != null &&
      _aTextAlphaNumeric.hasMatch(email) &&
      email.contains('@');
  static final RegExp _aTextAlphaNumeric =
      RegExp(r"^[a-zA-Z0-9@.!#$%&'*+\-/=?^_`{|}~]+$");
  String urlDecode(String encoded) {
    try {
      //todo decodeFull or decodeComponent or decodeQueryComponent ?
      return Uri.decodeQueryComponent(encoded, encoding: utf8);
    } catch (_) {
      // UnsupportedEncodingException
      rethrow; // can't happen
    }
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
}
