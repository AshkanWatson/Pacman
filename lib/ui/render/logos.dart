import 'dart:typed_data';

import 'dart:ui';

/// Vector geometry for the language logos used as character skins.
///
/// Everything is built once from path data, so the sprites look identical
/// on every platform and at every size, and nothing depends on fonts or
/// image assets.
abstract final class Logos {
  static const Color pythonBlue = Color(0xFF3776AB);
  static const Color pythonYellow = Color(0xFFFFD43B);
  static const Color jsYellow = Color(0xFFF7DF1E);
  static const Color jsInk = Color(0xFF1B1B1B);
  static const Color tsBlue = Color(0xFF3178C6);

  /// The two snakes of the Python logo, centred on the origin and scaled so
  /// the logo fits a 1 x 1 box. Each snake's eye is a hole (even-odd fill).
  static final Path pythonBlueSnake = _normalisePython(_blueSnake());
  static final Path pythonYellowSnake = _normalisePython(_yellowSnake());

  // Path data of the Python logo (no text), in its native ~111 x 113 box.
  static Path _blueSnake() => Path()
    ..fillType = PathFillType.evenOdd
    ..moveTo(54.919, 0)
    ..cubicTo(50.335, 0.021, 45.957, 0.412, 42.106, 1.094)
    ..cubicTo(30.760, 3.098, 28.700, 7.294, 28.700, 15.032)
    ..lineTo(28.700, 25.251)
    ..lineTo(55.513, 25.251)
    ..lineTo(55.513, 28.657)
    ..lineTo(18.638, 28.657)
    ..cubicTo(10.846, 28.657, 4.022, 33.341, 1.888, 42.251)
    ..cubicTo(-0.574, 52.464, -0.683, 58.837, 1.888, 69.501)
    ..cubicTo(3.794, 77.439, 8.346, 83.095, 16.138, 83.095)
    ..lineTo(25.356, 83.095)
    ..lineTo(25.356, 70.845)
    ..cubicTo(25.356, 61.995, 33.013, 54.188, 42.106, 54.188)
    ..lineTo(68.888, 54.188)
    ..cubicTo(76.342, 54.188, 82.294, 48.050, 82.294, 40.563)
    ..lineTo(82.294, 15.032)
    ..cubicTo(82.294, 7.766, 76.164, 2.307, 68.888, 1.094)
    ..cubicTo(64.282, 0.327, 59.503, -0.021, 54.919, 0)
    ..close()
    ..addOval(
      Rect.fromCircle(center: const Offset(40.419, 13.33), radius: 5.1),
    );

  static Path _yellowSnake() => Path()
    ..fillType = PathFillType.evenOdd
    ..moveTo(85.638, 28.657)
    ..lineTo(85.638, 40.563)
    ..cubicTo(85.638, 49.794, 77.812, 57.563, 68.888, 57.563)
    ..lineTo(42.106, 57.563)
    ..cubicTo(34.770, 57.563, 28.700, 63.842, 28.700, 71.188)
    ..lineTo(28.700, 96.720)
    ..cubicTo(28.700, 103.986, 35.019, 108.261, 42.106, 110.345)
    ..cubicTo(50.593, 112.840, 58.732, 113.291, 68.888, 110.345)
    ..cubicTo(75.638, 108.390, 82.294, 104.456, 82.294, 96.720)
    ..lineTo(82.294, 86.501)
    ..lineTo(55.513, 86.501)
    ..lineTo(55.513, 83.095)
    ..lineTo(95.700, 83.095)
    ..cubicTo(103.494, 83.095, 106.398, 77.659, 109.106, 69.501)
    ..cubicTo(111.904, 61.102, 111.785, 53.026, 109.106, 42.251)
    ..cubicTo(107.182, 34.493, 103.505, 28.657, 95.700, 28.657)
    ..close()
    ..addOval(
      Rect.fromCircle(center: const Offset(70.575, 98.42), radius: 5.1),
    );

  static Path _normalisePython(Path p) {
    // Native bounds are roughly (0, 0) - (111, 112.6).
    const cx = 55.5;
    const cy = 56.3;
    const size = 112.6;
    final m = Float64List(16)
      ..[0] = 1 / size
      ..[5] = 1 / size
      ..[10] = 1
      ..[15] = 1
      ..[12] = -cx / size
      ..[13] = -cy / size;
    return p.transform(m)..fillType = PathFillType.evenOdd;
  }

  // ------------------------------------------------------------------
  // Letters for the JS / TS logos, as strokes in a box whose cap height
  // is 1 (x grows right, y grows down). Stroke with [letterWeight].
  // ------------------------------------------------------------------

  static const double letterWeight = 0.2;
  static const double letterWidth = 0.62;
  static const double letterGap = 0.1;

  static final Path letterJ = Path()
    ..moveTo(0.46, 0)
    ..lineTo(0.46, 0.66)
    ..quadraticBezierTo(0.46, 0.9, 0.24, 0.9)
    ..quadraticBezierTo(0.08, 0.9, 0.02, 0.76);

  static final Path letterS = Path()
    ..moveTo(0.54, 0.2)
    ..quadraticBezierTo(0.48, 0.1, 0.3, 0.1)
    ..quadraticBezierTo(0.1, 0.1, 0.1, 0.28)
    ..quadraticBezierTo(0.1, 0.43, 0.32, 0.49)
    ..quadraticBezierTo(0.56, 0.56, 0.56, 0.71)
    ..quadraticBezierTo(0.56, 0.9, 0.31, 0.9)
    ..quadraticBezierTo(0.1, 0.9, 0.04, 0.78);

  static final Path letterT = Path()
    ..moveTo(0.0, 0.1)
    ..lineTo(0.6, 0.1)
    ..moveTo(0.3, 0.1)
    ..lineTo(0.3, 0.9);
}
