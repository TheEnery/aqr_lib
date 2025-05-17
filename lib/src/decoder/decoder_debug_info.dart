import 'package:image/image.dart';

import 'package:aqr_lib/src/core/aqr_code.dart';

class DecoderDebugInfo {
  Image? wbImage;
  Image? wbDetectedImage;
  Image? detectedImage;
  Image? colorCorrectedImage;
  Image? colorDistributionImage;
  Image? correctedImage;
  Image? errorImage;
  AqrCode? compareWith;
  int errorCount = 0;
}
