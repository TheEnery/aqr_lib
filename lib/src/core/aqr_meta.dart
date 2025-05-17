import 'compression.dart';
import 'error_correction.dart';
import 'mask.dart';

class AqrMeta {
  Compression compression;
  ErrorCorrection errorCorrection;
  Mask? mask;

  AqrMeta({
    required this.compression,
    this.errorCorrection = ErrorCorrection.M,
    this.mask,
  });
}
