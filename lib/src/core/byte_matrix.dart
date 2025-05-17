import 'dart:typed_data';

class ByteMatrix {
  final List<Uint8List> _columns;
  final int height;
  final int width;

  ByteMatrix.square({required int dimension})
      : this(height: dimension, width: dimension);

  ByteMatrix({required this.height, required this.width})
      : _columns = List.generate(width, (_) => Uint8List(height));

  Uint8List operator [](int index) => _columns[index];

  void fill(int byte) {
    for (final column in _columns) {
      for (int i = 0; i < height; i++) {
        column[i] = byte;
      }
    }
  }
}
