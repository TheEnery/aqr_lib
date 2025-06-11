import 'package:image/image.dart' show copyResize;
import 'package:test/test.dart';

import 'package:aqr_lib/core.dart';
import 'package:aqr_lib/decoder.dart';
import 'package:aqr_lib/encoder.dart';

void main() {
  int height = 500, width = 500;

  late AqrMeta meta;
  setUp(() => meta =
      AqrMeta(compression: Compression(level: 0), mask: Mask(number: 0)));

  group('Test different modes of encoding in the flow', () {
    test('numeric data should be processed', () {
      final data = '1234567890';
      final aqr = Encoder().encodeSegments(
        data: [Segment(content: data, mode: Mode.numeric)],
        meta: meta,
      );
      final image = copyResize(aqr.draw(), height: height, width: width);
      final lrgb = LrgbMatrix.fromImage(image);
      final result = Decoder().decode(lrgb);

      expect(data, result.text);
    });

    test('alphanumeric data should be processed', () {
      final data = '1A2B3C4D5E6F7G8H9I0J';
      final aqr = Encoder().encodeSegments(
        data: [Segment(content: data, mode: Mode.alphanumeric)],
        meta: meta,
      );
      final image = copyResize(aqr.draw(), height: height, width: width);
      final lrgb = LrgbMatrix.fromImage(image);
      final result = Decoder().decode(lrgb);

      expect(data, result.text);
    });

    test('byte data should be processed', () {
      final data = 'abcdefghij';
      final aqr = Encoder().encodeSegments(
        data: [Segment(content: data, mode: Mode.byte)],
        meta: meta,
      );
      final image = copyResize(aqr.draw(), height: height, width: width);
      final lrgb = LrgbMatrix.fromImage(image);
      final result = Decoder().decode(lrgb);

      expect(data, result.text);
    });

    test('kanji data should be processed', () {
      final data = '金曜日';
      final aqr = Encoder().encodeSegments(
        data: [Segment(content: data, mode: Mode.kanji)],
        meta: meta,
      );
      final image = copyResize(aqr.draw(), height: height, width: width);
      final lrgb = LrgbMatrix.fromImage(image);
      final result = Decoder().decode(lrgb);

      expect(data, result.text);
    });
  });
}
