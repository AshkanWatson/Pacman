import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../game/core/direction.dart';
import '../../game/entities/js_ghost.dart';
import '../theme.dart';

/// Vector sprites shared by the game board, the menu attract mode and the
/// "How to play" screen. All drawing happens in tile units: callers scale
/// the canvas so one unit equals one maze tile.
class SpriteKit {
  SpriteKit() {
    _jsLabel = _label('JS', const Color(0xFF111111));
    _tsLabel = _label('TS', const Color(0xFFFFFFFF));
    _tsLabelFlash = _label('TS', Palette.tsBlue);
  }

  late final TextPainter _jsLabel;
  late final TextPainter _tsLabel;
  late final TextPainter _tsLabelFlash;

  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Path _path = Path();

  static const double pythonRadius = 0.8;
  static const double ghostHalfWidth = 0.78;

  static TextPainter _label(String text, Color color) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: arcadeFont,
        fontSize: 0.42,
        color: color,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  void dispose() {
    _jsLabel.dispose();
    _tsLabel.dispose();
    _tsLabelFlash.dispose();
  }

  // --------------------------------------------------------------------
  // Python
  // --------------------------------------------------------------------

  /// Draws Python centred at ([cx], [cy]).
  ///
  /// [mouth] is the half-angle of the open mouth in radians (0..~0.9).
  /// [dying] (0..1) plays the "Traceback" collapse animation instead.
  void drawPython(
    Canvas canvas,
    double cx,
    double cy,
    Direction dir, {
    double mouth = 0.6,
    double dying = 0,
    double radius = pythonRadius,
  }) {
    canvas.save();
    canvas.translate(cx, cy);
    if (dying > 0) {
      // Face up and open the mouth until Python folds away, like the
      // arcade death sequence.
      canvas.rotate(-math.pi / 2);
      final collapse = (dying / 0.85).clamp(0.0, 1.0);
      mouth = 0.2 + collapse * (math.pi - 0.2);
      if (dying > 0.85) {
        _drawBurst(canvas, (dying - 0.85) / 0.15, radius);
        canvas.restore();
        return;
      }
    } else {
      switch (dir) {
        case Direction.left:
          canvas.scale(-1, 1);
        case Direction.up:
          canvas.rotate(-math.pi / 2);
        case Direction.down:
          canvas.rotate(math.pi / 2);
        case Direction.right:
        case Direction.none:
          break;
      }
    }

    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    _path
      ..reset()
      ..moveTo(0, 0)
      ..arcTo(rect, mouth, 2 * math.pi - 2 * mouth, false)
      ..close();

    // Lower half: Python yellow. Upper half: Python blue.
    _fill
      ..shader = null
      ..color = Palette.pythonYellow;
    canvas.drawPath(_path, _fill);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-radius, -radius, radius, 0));
    _fill.color = Palette.pythonBlueLight;
    canvas.drawPath(_path, _fill);
    canvas.restore();

    // Scale seam, a nod to the interlocking snakes of the logo.
    _stroke
      ..color = const Color(0x55000000)
      ..strokeWidth = 0.06;
    canvas.drawLine(Offset(-radius * 0.95, 0), Offset(-0.05, 0), _stroke);

    if (dying == 0) {
      // Eye.
      final eye = Offset(radius * 0.12, -radius * 0.5);
      _fill.color = const Color(0xFFFFFFFF);
      canvas.drawCircle(eye, radius * 0.17, _fill);
      _fill.color = const Color(0xFF0B1426);
      canvas.drawCircle(eye.translate(radius * 0.05, 0), radius * 0.09, _fill);
    }
    canvas.restore();
  }

  void _drawBurst(Canvas canvas, double t, double radius) {
    _stroke
      ..color = Palette.pythonYellow.withValues(alpha: 1 - t)
      ..strokeWidth = 0.1;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final r0 = radius * (0.3 + t * 0.4);
      final r1 = radius * (0.6 + t * 0.6);
      canvas.drawLine(
        Offset(math.cos(a) * r0, math.sin(a) * r0),
        Offset(math.cos(a) * r1, math.sin(a) * r1),
        _stroke,
      );
    }
  }

  // --------------------------------------------------------------------
  // Ghosts
  // --------------------------------------------------------------------

  /// Draws a JavaScript ghost (or its TypeScript form) centred at ([cx],
  /// [cy]). [wobble] alternates the skirt animation frame.
  void drawGhost(
    Canvas canvas,
    double cx,
    double cy,
    GhostKind kind,
    Direction dir, {
    bool typescript = false,
    bool flashWhite = false,
    bool eyesOnly = false,
    bool wobble = false,
  }) {
    canvas.save();
    canvas.translate(cx, cy);
    const hw = ghostHalfWidth;

    if (!eyesOnly) {
      final Color body;
      final TextPainter label;
      if (typescript) {
        body = flashWhite ? const Color(0xFFF2F4F8) : Palette.tsBlue;
        label = flashWhite ? _tsLabelFlash : _tsLabel;
      } else {
        body = Color(kind.color);
        label = _jsLabel;
      }
      _buildGhostBody(hw, wobble);
      _fill
        ..shader = null
        ..color = body;
      canvas.drawPath(_path, _fill);
      // Logo-style label in the bottom-right corner, like the JS/TS logos.
      label.paint(canvas, Offset(hw - 0.1 - label.width, 0.5 - label.height));
    }

    if (typescript && !eyesOnly) {
      // Frightened face: small eyes and a squiggly mouth.
      final face = flashWhite ? Palette.danger : const Color(0xFFFFD7C2);
      _fill.color = face;
      canvas.drawRect(const Rect.fromLTWH(-0.34, -0.5, 0.16, 0.16), _fill);
      canvas.drawRect(const Rect.fromLTWH(0.18, -0.5, 0.16, 0.16), _fill);
      _stroke
        ..color = face
        ..strokeWidth = 0.07;
      _path.reset();
      _path.moveTo(-0.5, -0.1);
      for (var i = 0; i < 6; i++) {
        _path.lineTo(-0.5 + (i + 0.5) * 0.17, i.isEven ? -0.2 : -0.1);
      }
      canvas.drawPath(_path, _stroke);
    } else {
      _drawEyes(canvas, dir);
    }
    canvas.restore();
  }

  void _buildGhostBody(double hw, bool wobble) {
    // hw is the half width of the body.
    const top = -0.78;
    const skirt = 0.6;
    const feet = 0.8;
    _path
      ..reset()
      ..moveTo(-hw, skirt)
      ..lineTo(-hw, top + hw)
      ..arcToPoint(Offset(hw, top + hw), radius: Radius.circular(hw))
      ..lineTo(hw, skirt);
    // Wavy skirt with two animation frames.
    const bumps = 4;
    final step = (2 * hw) / bumps;
    for (var i = 0; i < bumps; i++) {
      final x0 = hw - i * step;
      final mid = x0 - step / 2;
      final x1 = x0 - step;
      if (wobble) {
        _path
          ..lineTo(mid, feet)
          ..lineTo(x1, skirt);
      } else {
        _path
          ..lineTo(x0 - step * 0.25, feet)
          ..lineTo(x0 - step * 0.75, feet)
          ..lineTo(x1, skirt);
      }
    }
    _path.close();
  }

  void _drawEyes(Canvas canvas, Direction dir) {
    final look = Offset(dir.dx * 0.11, dir.dy * 0.12);
    for (final side in const [-0.3, 0.3]) {
      final centre = Offset(side, -0.22) + look * 0.5;
      _fill.color = const Color(0xFFFFFFFF);
      canvas.drawOval(
        Rect.fromCenter(center: centre, width: 0.4, height: 0.5),
        _fill,
      );
      _fill.color = const Color(0xFF1B3FA8);
      canvas.drawCircle(centre + look, 0.12, _fill);
    }
  }
}

/// Builds the neon maze-wall picture in tile units.
///
/// Each wall tile is split into four quadrants; every quadrant draws a
/// straight edge, an outer rounded corner or an inner corner depending on
/// its neighbours. The result is the continuous rounded outline of the
/// arcade maze.
ui.Picture buildWallPicture(
  bool Function(int col, int row) isWall,
  int width,
  int height, {
  Color color = Palette.wall,
  Color glow = Palette.wallGlow,
  bool withGlow = true,
}) {
  const inset = 0.36; // distance of the outline from the corridor
  const r = 0.5 - inset;
  final path = Path();

  for (var row = 0; row < height; row++) {
    for (var col = 0; col < width; col++) {
      if (!isWall(col, row)) continue;
      final cx = col + 0.5;
      final cy = row + 0.5;
      for (final (sx, sy) in const [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
        final h = isWall(col + sx, row);
        final v = isWall(col, row + sy);
        final d = isWall(col + sx, row + sy);
        if (!h && !v) {
          // Outer corner: quarter circle around the tile centre.
          final start = Offset(cx + sx * r, cy);
          path.moveTo(start.dx, start.dy);
          path.arcToPoint(
            Offset(cx, cy + sy * r),
            radius: const Radius.circular(r),
            clockwise: sx * sy > 0,
          );
        } else if (h && !v) {
          path.moveTo(cx, cy + sy * r);
          path.lineTo(cx + sx * 0.5, cy + sy * r);
        } else if (!h && v) {
          path.moveTo(cx + sx * r, cy);
          path.lineTo(cx + sx * r, cy + sy * 0.5);
        } else if (!d) {
          // Inner corner around the diagonal gap.
          final corner = Offset(cx + sx * 0.5, cy + sy * 0.5);
          path.moveTo(corner.dx, corner.dy - sy * inset);
          path.arcToPoint(
            Offset(corner.dx - sx * inset, corner.dy),
            radius: const Radius.circular(inset),
            clockwise: sx * sy < 0,
          );
        }
      }
    }
  }

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (withGlow) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.32
        ..color = glow.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.18),
    );
  }
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.14
      ..strokeCap = StrokeCap.round
      ..color = color,
  );
  return recorder.endRecording();
}

/// Draws a semicolon collectible centred in tile ([col], [row]).
void addSemicolon(Canvas canvas, Paint paint, double cx, double cy) {
  canvas.drawCircle(Offset(cx, cy - 0.17), 0.1, paint);
  canvas.drawCircle(Offset(cx, cy + 0.1), 0.1, paint);
  final tail = Path()
    ..moveTo(cx + 0.09, cy + 0.12)
    ..quadraticBezierTo(cx + 0.06, cy + 0.3, cx - 0.1, cy + 0.36)
    ..quadraticBezierTo(cx + 0.0, cy + 0.24, cx - 0.04, cy + 0.16)
    ..close();
  canvas.drawPath(tail, paint);
}
