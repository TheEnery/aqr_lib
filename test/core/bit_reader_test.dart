import 'package:test/test.dart';

import 'package:aqr_lib/src/core/bit_writer.dart';

void main() {
  group('Test reading from BitReader', () {
    test('random single bits should be read', () {
      final writer = BitWriter()
        ..addInt(0xB6, 8)
        ..add(true);
      final reader = writer.reader;

      expect(reader[3], true);
      expect(reader[2], true);
      expect(reader[1], false);
      expect(reader[0], true);

      expect(reader[7], false);
      expect(reader[6], true);
      expect(reader[5], true);
      expect(reader[4], false);

      expect(reader[8], true);

      expect(reader.available, 9);
    });

    test('single bits should be read', () {
      final writer = BitWriter()..addInt(0xA4, 8);
      final reader = writer.reader;

      expect(reader.get(), true);
      expect(reader.get(), false);
      expect(reader.get(), true);
      expect(reader.get(), false);
      expect(reader.get(), false);
      expect(reader.get(), true);
      expect(reader.get(), false);
      expect(reader.get(), false);
    });

    test('multiple bits should be read', () {
      final writer = BitWriter()
        ..addInt(0x12345678, 32)
        ..addInt(0x9ABCDEF0, 32)
        ..addInt(0x12345678, 32)
        ..addInt(0x9ABCDEF0, 32);
      final reader = writer.reader;

      expect(reader.getInt(1), 0x0);
      expect(reader.getInt(3), 0x1);
      expect(reader.getInt(4), 0x2);
      expect(reader.getInt(8), 0x34);
      expect(reader.getInt(24), 0x56789A);
      expect(reader.getInt(16), 0xBCDE);
      expect(reader.getInt(8), 0xF0);
      expect(reader.getInt(32), 0x12345678);
      expect(reader.getInt(0), 0x0);
      expect(reader.getInt(32), 0x9ABCDEF0);
    });

    test('on invalid bitCount getInt should throw', () {
      final writer = BitWriter()..addInt(0x12345678, 32);
      final reader = writer.reader;

      expect(() => reader.getInt(33), throwsRangeError);
      expect(() => reader.getInt(-1), throwsRangeError);
    });

    test('attempts to read more should throw', () {
      final writer = BitWriter()..addInt(0x1, 2);
      final reader = writer.reader;

      expect(() => reader.getInt(4), throwsRangeError);
    });

    test('data property should return bytes with expected order', () {
      final writer = BitWriter()
        ..addInt(0x12345678, 32)
        ..addInt(0x9ABC, 16);
      final reader = writer.reader;
      final bytes = reader.data;

      expect(bytes[0], 0x12);
      expect(bytes[1], 0x34);
      expect(bytes[2], 0x56);
      expect(bytes[3], 0x78);
      expect(bytes[4], 0x9A);
      expect(bytes[5], 0xBC);
      expect(bytes.lengthInBytes, 6);
    });
  });
}
