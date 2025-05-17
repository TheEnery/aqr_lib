import 'package:image/image.dart';

import 'aqr_meta.dart';
import 'byte_matrix.dart';

class AqrCode {
  ByteMatrix data;
  AqrMeta meta;

  AqrCode({required this.data, required this.meta});

  Image draw({int quietZoneSize = 4}) {
    final image = Image(
        width: data.width + 2 * quietZoneSize,
        height: data.height + 2 * quietZoneSize);

    fill(image, color: meta.compression.palette[0]);

    for (int x = 0; x < data.width; x++) {
      final column = data[x];
      for (int y = 0; y < data.height; y++) {
        final color = meta.compression.palette[column[y]];
        fillRect(
          image,
          x1: x + quietZoneSize,
          y1: y + quietZoneSize,
          x2: x + quietZoneSize,
          y2: y + quietZoneSize,
          color: color,
        );
      }
    }

    return image;
  }
}
