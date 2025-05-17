import 'package:image/image.dart';

class Compression {
  static const int minLevel = 0;
  static const int maxLevel = 3;
  static final defaultPalette = _defaultPalette;

  final int level;
  late final List<Color> palette;

  int get bitMask => (2 << level) - 1;
  int get bitsPerModule => level + 1;
  int get darkestValue => 1 << level;
  int get paletteSize => 2 << level;
  bool get isMin => minLevel == level;
  bool get isNotMin => minLevel != level;

  Compression({required this.level}) : palette = defaultPalette[level];

  Compression.withCustomPalette({required this.level, required this.palette}) {
    RangeError.checkValueInInterval(level, minLevel, maxLevel, 'level');
    //_preparePalette();
  }

  static final _defaultPalette = [
    [
      hslToRgb(0, 1, 1),
      hslToRgb(0, 1, 0),
    ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),
    [
      hslToRgb(0, 1, 1),
      hslToRgb(120 / 360, 1, 0.75),
      hslToRgb(0, 1, 0),
      hslToRgb(120 / 360, 1, 0.25),
    ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),

    // [
    //   hslToRgb(0, 1, 1),
    //   hslToRgb(180 / 360, 1, 0.6),
    //   hslToRgb(0, 1, 0),
    //   hslToRgb(180 / 360, 1, 0.4),
    // ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),
    // [
    //   [255, 255, 255],
    //   rgb(3, 190, 88), //oklch(0.7 0.1923 150)
    //   [0, 0, 0],
    //   rgb(1, 120, 53), //oklch(0.5 0.1375 150)
    // ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),
    // [
    //   [255, 255, 255],
    //   rgb(4, 178, 200), //oklch(0.7 0.1206 210)
    //   [0, 0, 0],
    //   rgb(0, 112, 126), //oklch(0.5 0.0864 210)
    // ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),

    [
      hslToRgb(0, 1, 1),
      hslToRgb(000 / 360, 1, 0.7),
      hslToRgb(120 / 360, 1, 0.6),
      hslToRgb(240 / 360, 1, 0.7),
      hslToRgb(0, 1, 0),
      hslToRgb(000 / 360, 1, 0.3),
      hslToRgb(120 / 360, 1, 0.2),
      hslToRgb(240 / 360, 1, 0.2),
    ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),
    // [
    //   hslToRgb(0, 1, 1),
    //   hslToRgb(060 / 360, 1, 0.4),
    //   hslToRgb(180 / 360, 1, 0.6),
    //   hslToRgb(300 / 360, 1, 0.6),
    //   hslToRgb(0, 1, 0),
    //   hslToRgb(060 / 360, 1, 0.3),
    //   hslToRgb(180 / 360, 1, 0.4),
    //   hslToRgb(300 / 360, 1, 0.4),
    // ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),
    // [
    //   [255, 255, 255],
    //   rgb(255, 101, 81), //oklch(0.7 0.1913 30)
    //   rgb(3, 190, 88), //oklch(0.7 0.1923 150)
    //   rgb(121, 151, 255), //oklch(0.7 0.1559 270)
    //   [0, 0, 0],
    //   rgb(187, 12, 0), //oklch(0.5 0.2005 30)
    //   rgb(1, 120, 53), //oklch(0.5 0.1375 150)
    //   rgb(52, 53, 255), //oklch(0.5 0.2809 270)
    // ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),
    // [
    //   hslToRgb(0, 1, 1),
    //   hslToRgb(000 / 360, 1, 0.6),
    //   hslToRgb(060 / 360, 1, 0.4),
    //   hslToRgb(120 / 360, 1, 0.5),
    //   hslToRgb(180 / 360, 1, 0.6),
    //   hslToRgb(240 / 360, 1, 0.6),
    //   hslToRgb(300 / 360, 1, 0.6),
    //   hslToRgb(0, 0, 0.75),
    //   hslToRgb(0, 1, 0),
    //   hslToRgb(000 / 360, 1, 0.4),
    //   hslToRgb(060 / 360, 1, 0.3),
    //   hslToRgb(120 / 360, 1, 0.3),
    //   hslToRgb(180 / 360, 1, 0.4),
    //   hslToRgb(240 / 360, 1, 0.3),
    //   hslToRgb(300 / 360, 1, 0.4),
    //   hslToRgb(0, 0, 0.25),
    // ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),
    [
      hslToRgb(0, 1, 1),
      hslToRgb(000 / 360, 1, 0.7),
      hslToRgb(060 / 360, 1, 0.5),
      hslToRgb(120 / 360, 1, 0.6),
      hslToRgb(180 / 360, 1, 0.7),
      hslToRgb(240 / 360, 1, 0.7),
      hslToRgb(300 / 360, 1, 0.7),
      hslToRgb(0, 0, 0.6),
      hslToRgb(0, 1, 0),
      hslToRgb(000 / 360, 1, 0.3),
      hslToRgb(060 / 360, 1, 0.2),
      hslToRgb(120 / 360, 1, 0.2),
      hslToRgb(180 / 360, 1, 0.3),
      hslToRgb(240 / 360, 1, 0.2),
      hslToRgb(300 / 360, 1, 0.3),
      hslToRgb(0, 0, 0.4),
    ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),
    // [
    //   hslToRgb(0, 1, 1),
    //   hslToRgb(000 / 360, 1, 0.75),
    //   hslToRgb(060 / 360, 1, 0.75),
    //   hslToRgb(120 / 360, 1, 0.75),
    //   hslToRgb(180 / 360, 1, 0.75),
    //   hslToRgb(240 / 360, 1, 0.75),
    //   hslToRgb(300 / 360, 1, 0.75),
    //   hslToRgb(0, 0, 0.75),
    //   hslToRgb(0, 1, 0),
    //   hslToRgb(000 / 360, 1, 0.25),
    //   hslToRgb(060 / 360, 1, 0.25),
    //   hslToRgb(120 / 360, 1, 0.25),
    //   hslToRgb(180 / 360, 1, 0.25),
    //   hslToRgb(240 / 360, 1, 0.25),
    //   hslToRgb(300 / 360, 1, 0.25),
    //   hslToRgb(0, 0, 0.35),
    // ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),
    // [
    //   [255, 255, 255],
    //   rgb(255, 101, 81), //oklch(0.7 0.1913 30)
    //   rgb(193, 153, 1), //oklch(0.7 0.1429 90)
    //   rgb(3, 190, 88), //oklch(0.7 0.1923 150)
    //   rgb(4, 178, 200), //oklch(0.7 0.1206 210)
    //   rgb(121, 151, 255), //oklch(0.7 0.1559 270)
    //   rgb(255, 19, 247), //oklch(0.7 0.3135 330)
    //   rgb(158, 158, 158), //oklch(0.7 0 330)
    //   [0, 0, 0],
    //   rgb(187, 12, 0), //oklch(0.5 0.2005 30)
    //   rgb(122, 96, 0), //oklch(0.5 0.1021 90)
    //   rgb(1, 120, 53), //oklch(0.5 0.1375 150)
    //   rgb(0, 112, 126), //oklch(0.5 0.0864 210)
    //   rgb(52, 53, 255), //oklch(0.5 0.2809 270)
    //   rgb(163, 0, 158), //oklch(0.5 0.2277 330)
    //   rgb(99, 99, 99), //oklch(0.5 0 330)
    // ].map((rgb) => ColorRgb8(rgb[0], rgb[1], rgb[2])).toList(),
  ];

  void _preparePalette() {
    if (paletteSize != palette.length) {
      throw Exception();
    }

    palette.sort((c1, c2) => c2.luminance.compareTo(c1.luminance));

    palette.reduce((c1, c2) {
      if (c1.luminance - c2.luminance < _minLumaDifference) {
        print(c1);
        print(c2);
        print(c1.luminance - c2.luminance);
        //throw Exception();
      }
      return c2;
    });

    final middle = paletteSize ~/ 2;
    palette.setAll(middle, palette.sublist(middle).reversed);
  }

  static const _minLumaDifference = 5;
}

List<int> rgb(int r, int g, int b) => [r, g, b];

// List<int> oklchToRgb(num h, num c, num l) {
//   // Перетворення HCL -> LAB
//   double H = h * 2 * pi; // кут у радіанах
//   double a = c * cos(H);
//   double b = c * sin(H);

//   // Масштабування назад
//   a *= 0.4;
//   b *= 0.4;

//   // OKLab до LMS
//   double l_ = l.toDouble();
//   double m_ = l_ - 0.2104542553 * a - 0.0259040371 * b;
//   double s_ = l_ + 0.0040720468 * a + 0.8086757660 * b;

//   double lCube = pow(l_ + 0.3963377774 * a + 0.2158037573 * b, 3).toDouble();
//   double mCube = pow(m_, 3).toDouble();
//   double sCube = pow(s_, 3).toDouble();

//   // LMS -> linear RGB
//   double R = 4.0767416621 * lCube - 3.3077115913 * mCube + 0.2309699292 * sCube;
//   double G =
//       -1.2684380046 * lCube + 2.6097574011 * mCube - 0.3413193965 * sCube;
//   double B =
//       -0.0041960863 * lCube - 0.7034186147 * mCube + 1.7076147010 * sCube;

//   // Лінійне до sRGB
//   // R = R <= 0.0031308 ? R * 12.92 : 1.055 * pow(R, 1 / 2.4) - 0.055;
//   // G = G <= 0.0031308 ? G * 12.92 : 1.055 * pow(G, 1 / 2.4) - 0.055;
//   // B = B <= 0.0031308 ? B * 12.92 : 1.055 * pow(B, 1 / 2.4) - 0.055;

//   // Кліпінг і масштабування до 0–255
//   return [
//     (max(0, min(1, R)) * 255).round(),
//     (max(0, min(1, G)) * 255).round(),
//     (max(0, min(1, B)) * 255).round(),
//   ];
// }
