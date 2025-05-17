import 'package:test/test.dart';

import 'package:aqr_lib/src/core/bit_writer.dart';

void main() {
  group('Test writing to BitWriter', () {
    test('single bits should be added', () {
      final writer = BitWriter();

      writer.add(true);
      writer.add(true);
      writer.add(false);
      writer.add(true);
      writer.add(false);
      writer.add(false);
      writer.add(true);
      writer.add(false);

      writer.add(true);

      expect(writer.data[0], 0xD2);
      expect(writer.data[1], 0x80);
      expect(writer.length, 9);
    });

    test('multiple bits should be added', () {
      final writer = BitWriter();

      writer.addInt(0x0, 1);
      writer.addInt(0x1, 3);
      writer.addInt(0x2, 4);
      writer.addInt(0x34, 8);
      writer.addInt(0x56789A, 24);
      writer.addInt(0xBCDE, 16);
      writer.addInt(0xF0, 8);

      writer.addInt(0x12345678, 32);
      writer.addInt(0xFFFFFF9A, 8);
      writer.addInt(0xFFFFFFBCDEF0, 24);

      expect(writer.data[0], 0x12);
      expect(writer.data[1], 0x34);
      expect(writer.data[2], 0x56);
      expect(writer.data[3], 0x78);
      expect(writer.data[4], 0x9A);
      expect(writer.data[5], 0xBC);
      expect(writer.data[6], 0xDE);
      expect(writer.data[7], 0xF0);

      expect(writer.data[8], 0x12);
      expect(writer.data[9], 0x34);
      expect(writer.data[10], 0x56);
      expect(writer.data[11], 0x78);
      expect(writer.data[12], 0x9A);
      expect(writer.data[13], 0xBC);
      expect(writer.data[14], 0xDE);
      expect(writer.data[15], 0xF0);

      expect(writer.length, 128);
    });

    test('on invalid bitCount addInt should throw', () {
      final writer = BitWriter();

      expect(() => writer.addInt(0x1, 33), throwsRangeError);
      expect(() => writer.addInt(0x1, -1), throwsRangeError);
    });

    test('bits from BitReader should be added', () {
      final receiver = BitWriter()
        ..addInt(0x12345678, 32)
        ..addInt(0x9A, 8);
      final source = BitWriter()
        ..addInt(0xBCDEF012, 32)
        ..addInt(0x3456, 16);

      receiver.addOther(source.reader);

      expect(receiver.data[0], 0x12);
      expect(receiver.data[1], 0x34);
      expect(receiver.data[2], 0x56);
      expect(receiver.data[3], 0x78);
      expect(receiver.data[4], 0x9A);
      expect(receiver.data[5], 0xBC);
      expect(receiver.data[6], 0xDE);
      expect(receiver.data[7], 0xF0);

      expect(receiver.data[8], 0x12);
      expect(receiver.data[9], 0x34);
      expect(receiver.data[10], 0x56);

      expect(receiver.length, 88);
    });
  });
}
