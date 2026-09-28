import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../game/core/direction.dart';
import '../../game/entities/js_ghost.dart';
import '../theme.dart';
import 'logos.dart';

/// Vector sprites shared by the game board, the menu attract mode and the
/// "How to play" screen. All drawing happens in tile units: callers scale
/// the canvas so one unit equals one maze tile.
///
/// Characters wear language logos as skins: Python is the Python logo (with
/// a chomping mouth cut out of it), ghosts are the JavaScript logo, and
/// powered-up ghosts become the TypeScript logo. Skins are purely visual:
/// sizes are fixed per sprite, so collisions never depend on logo shape.
class SpriteKit {
  final Paint _fill = Paint()..isAntiAlias = true;
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _letter = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = Logos.letterWeight;
  final Path _path = Path();

  /// Python's visual radius (the logo fits a 2r x 2r box).
  static const double pythonRadius = 0.8;

  /// Half the side of the JS/TS logo squares.
  static const double ghostHalfWidth = 0.76;

  /// Kept for API symmetry; nothing to release (no text painters/images).
  void dispose() {}

  // --------------------------------------------------------------------
  // Python
  // --------------------------------------------------------------------

  /// Draws Python centred at ([cx], [cy]).
  ///
  /// [mouth] is the half-angle of the open mouth in radians (0..~0.9); the
  /// mouth is cut out of the logo in the direction of travel while the logo
  /// itself stays upright so it is always recognisable.
  /// [dying] (0..1) plays the arcade-style collapse animation instead.
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

    var facing = switch (dir) {
      Direction.left => math.pi,
      Direction.up => -math.pi / 2,
      Direction.down => math.pi / 2,
      Direction.right || Direction.none => 0.0,
    };
    if (dying > 0) {
      // Face up and open wider and wider until Python is gone, like the
      // arcade death sequence, then a small "exception" burst.
      facing = -math.pi / 2;
      if (dying > 0.85) {
        _drawBurst(canvas, (dying - 0.85) / 0.15, radius);
        canvas.restore();
        return;
      }
      final collapse = (dying / 0.85).clamp(0.0, 1.0);
      mouth = 0.2 + collapse * (math.pi - 0.2);
    }

    if (mouth > 0.01) {
      // Clip to a "pie" shape: everything except the mouth wedge.
      final r = radius * 1.6;
      _path
        ..reset()
        ..moveTo(0, 0)
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: r),
          facing + mouth,
          2 * math.pi - 2 * mouth,
          false,
        )
        ..close();
      canvas.clipPath(_path);
    }

    canvas.scale(radius * 2);
    _fill
      ..shader = null
      ..color = Logos.pythonBlue;
    canvas.drawPath(Logos.pythonBlueSnake, _fill);
    _fill.color = Logos.pythonYellow;
    canvas.drawPath(Logos.pythonYellowSnake, _fill);
    canvas.restore();
  }

  void _drawBurst(Canvas canvas, double t, double radius) {
    for (var i = 0; i < 8; i++) {
      _stroke
        ..color = (i.isEven ? Logos.pythonBlue : Logos.pythonYellow).withValues(
          alpha: 1 - t,
        )
        ..strokeWidth = 0.1;
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
  // Ghosts: JavaScript logo, TypeScript logo when powered
  // --------------------------------------------------------------------

  /// Draws a JavaScript ghost (or its TypeScript form) centred at ([cx],
  /// [cy]).
  ///
  /// [wobble] alternates a two-frame "hover" animation, [scaleX] (0..1)
  /// squeezes the logo horizontally for the JS <-> TS flip transition, and
  /// [eyesOnly] draws just the eyes of an eaten ghost heading home.
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
    double scaleX = 1,
  }) {
    canvas.save();
    canvas.translate(cx, cy + (wobble ? -0.035 : 0.035));
    if (eyesOnly) {
      _drawEyes(canvas, dir);
      canvas.restore();
      return;
    }
    canvas.scale(scaleX.clamp(0.06, 1.0), 1);

    const hw = ghostHalfWidth;
    final square = RRect.fromRectAndRadius(
      const Rect.fromLTRB(-hw, -hw, hw, hw),
      const Radius.circular(0.1),
    );

    final Color body;
    final Color ink;
    if (typescript) {
      body = flashWhite ? const Color(0xFFF2F4F8) : Logos.tsBlue;
      ink = flashWhite ? Logos.tsBlue : const Color(0xFFFFFFFF);
    } else {
      body = Logos.jsYellow;
      ink = Logos.jsInk;
    }
    _fill
      ..shader = null
      ..color = body;
    canvas.drawRRect(square, _fill);

    if (!typescript) {
      // Each JS ghost keeps its arcade colour as a thin frame so the four
      // personalities stay readable.
      _stroke
        ..color = Color(kind.color)
        ..strokeWidth = 0.08;
      canvas.drawRRect(square.deflate(0.04), _stroke);
    }

    _drawLetters(canvas, typescript ? 'TS' : 'JS', ink);

    if (typescript) {
      _drawFrightenedFace(canvas, flashWhite);
    } else {
      _drawEyes(canvas, dir, small: true);
    }
    canvas.restore();
  }

  /// Logo lettering in the bottom-right corner, like the real JS/TS logos.
  void _drawLetters(Canvas canvas, String letters, Color ink) {
    const hw = ghostHalfWidth;
    const cap = hw * 2 * 0.36; // cap height relative to the square
    const width = (Logos.letterWidth * 2 + Logos.letterGap) * cap;
    _letter
      ..color = ink
      ..strokeWidth = Logos.letterWeight;
    canvas.save();
    canvas.translate(hw * 0.86 - width, hw * 0.9 - cap);
    canvas.scale(cap);
    for (final ch in letters.split('')) {
      canvas.drawPath(switch (ch) {
        'J' => Logos.letterJ,
        'T' => Logos.letterT,
        _ => Logos.letterS,
      }, _letter);
      canvas.translate(Logos.letterWidth + Logos.letterGap, 0);
    }
    canvas.restore();
  }

  void _drawFrightenedFace(Canvas canvas, bool flashWhite) {
    final face = flashWhite ? Palette.danger : const Color(0xFFFFD7C2);
    _fill.color = face;
    canvas.drawRect(const Rect.fromLTWH(-0.5, -0.5, 0.14, 0.14), _fill);
    canvas.drawRect(const Rect.fromLTWH(-0.2, -0.5, 0.14, 0.14), _fill);
    _stroke
      ..color = face
      ..strokeWidth = 0.06;
    _path
      ..reset()
      ..moveTo(-0.56, -0.18);
    for (var i = 0; i < 5; i++) {
      _path.lineTo(-0.56 + (i + 1) * 0.1, i.isEven ? -0.26 : -0.18);
    }
    canvas.drawPath(_path, _stroke);
  }

  void _drawEyes(Canvas canvas, Direction dir, {bool small = false}) {
    final k = small ? 0.72 : 1.0;
    final look = Offset(dir.dx * 0.1, dir.dy * 0.1) * k;
    final centres = small
        ? const [Offset(-0.46, -0.32), Offset(-0.14, -0.32)]
        : const [Offset(-0.3, -0.22), Offset(0.3, -0.22)];
    for (final c in centres) {
      final centre = c + look * 0.5;
      _fill.color = const Color(0xFFFFFFFF);
      canvas.drawOval(
        Rect.fromCenter(center: centre, width: 0.4 * k, height: 0.5 * k),
        _fill,
      );
      _fill.color = const Color(0xFF1B3FA8);
      canvas.drawCircle(centre + look, 0.12 * k, _fill);
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
