class ErrorCorrection {
  static const L = ErrorCorrection._(0, 1);
  static const M = ErrorCorrection._(1, 0);
  static const Q = ErrorCorrection._(2, 3);
  static const H = ErrorCorrection._(3, 2);
  static const values = [L, M, Q, H];

  final int level;
  final int bits;

  const ErrorCorrection._(this.level, this.bits);

  factory ErrorCorrection({required int level}) {
    return const [L, M, Q, H][level];
  }

  factory ErrorCorrection.fromBits(int bits) {
    return const [M, L, H, Q][bits];
  }
}
