class Mask {
  static final values = _values;

  final int number;
  final bool Function(int x, int y) isMasked;

  Mask._(this.number, this.isMasked);

  factory Mask({required int number}) {
    return values[number];
  }

  static final _values = [
    /// (x + y) % 2 == 0
    Mask._(0, (x, y) => (x + y) & 1 == 0),

    /// y % 2 == 0
    Mask._(1, (_, y) => y & 1 == 0),

    /// x % 3 == 0
    Mask._(2, (x, _) => x % 3 == 0),

    /// (x + y) % 3 == 0
    Mask._(3, (x, y) => (x + y) % 3 == 0),

    /// ((y ~/ 2) + (x ~/ 3)) % 2 == 0
    Mask._(4, (x, y) => ((y ~/ 2) + (x ~/ 3)) & 1 == 0),

    /// (x * y) % 2 + (x * y) % 3 == 0
    Mask._(5, (x, y) => (x * y) % 6 == 0),

    /// ((x * y) % 2 + (x * y) % 3) % 2 == 0
    Mask._(6, (x, y) => (x * y) % 6 < 3),

    /// ((x + y) % 2 (x * y) % 3) % 2 == 0
    Mask._(7, (x, y) => (x + y + x * y % 3) & 1 == 0),
  ];
}
