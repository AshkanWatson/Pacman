import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/core/direction.dart';
import '../theme.dart';

/// Turns swipes anywhere on [child] into directions.
///
/// Uses raw pointer events (no gesture arena), so it never delays or
/// steals taps from buttons, and it re-anchors after each detected swipe so
/// a single continuous drag can steer through several corners.
class SwipeControls extends StatefulWidget {
  const SwipeControls({
    super.key,
    required this.onDirection,
    required this.child,
    this.threshold = 14,
  });

  final ValueChanged<Direction> onDirection;
  final Widget child;
  final double threshold;

  @override
  State<SwipeControls> createState() => _SwipeControlsState();
}

class _SwipeControlsState extends State<SwipeControls> {
  Offset? _anchor;
  int? _pointer;

  void _move(PointerEvent e) {
    if (e.pointer != _pointer || _anchor == null) return;
    final d = e.position - _anchor!;
    if (d.distance < widget.threshold) return;
    final dir = d.dx.abs() > d.dy.abs()
        ? (d.dx > 0 ? Direction.right : Direction.left)
        : (d.dy > 0 ? Direction.down : Direction.up);
    widget.onDirection(dir);
    _anchor = e.position;
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (e) {
      _pointer = e.pointer;
      _anchor = e.position;
    },
    onPointerMove: _move,
    onPointerUp: (e) {
      if (e.pointer == _pointer) _anchor = null;
    },
    onPointerCancel: (_) => _anchor = null,
    child: widget.child,
  );
}

/// An on-screen joystick-style D-pad. Touching (or dragging) anywhere on
/// the pad steers towards that side, so it can be used without looking.
class DirectionPad extends StatefulWidget {
  const DirectionPad({super.key, required this.onDirection, this.size = 150});

  final ValueChanged<Direction> onDirection;
  final double size;

  @override
  State<DirectionPad> createState() => _DirectionPadState();
}

class _DirectionPadState extends State<DirectionPad> {
  Direction _active = Direction.none;

  void _update(Offset local) {
    final c = Offset(widget.size / 2, widget.size / 2);
    final d = local - c;
    if (d.distance < widget.size * 0.12) return; // dead zone
    final a = math.atan2(d.dy, d.dx);
    final Direction dir;
    if (a > -math.pi / 4 && a <= math.pi / 4) {
      dir = Direction.right;
    } else if (a > math.pi / 4 && a <= 3 * math.pi / 4) {
      dir = Direction.down;
    } else if (a > -3 * math.pi / 4 && a <= -math.pi / 4) {
      dir = Direction.up;
    } else {
      dir = Direction.left;
    }
    if (dir != _active) {
      setState(() => _active = dir);
      widget.onDirection(dir);
    }
  }

  void _release() => setState(() => _active = Direction.none);

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Direction pad',
    child: Listener(
      onPointerDown: (e) => _update(e.localPosition),
      onPointerMove: (e) => _update(e.localPosition),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _PadPainter(_active)),
      ),
    ),
  );
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.active);
  final Direction active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r - 1,
      Paint()..color = Palette.surface.withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Palette.wall.withValues(alpha: 0.6),
    );
    for (final d in Direction.moving) {
      final on = d == active;
      final dirVec = Offset(d.dx.toDouble(), d.dy.toDouble());
      final tip = c + dirVec * (r * 0.78);
      final base = c + dirVec * (r * 0.42);
      final side = Offset(-dirVec.dy, dirVec.dx) * (r * 0.2);
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(base.dx + side.dx, base.dy + side.dy)
        ..lineTo(base.dx - side.dx, base.dy - side.dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = on
              ? Palette.pythonYellow
              : Palette.text.withValues(alpha: 0.35),
      );
    }
    canvas.drawCircle(
      c,
      r * 0.14,
      Paint()..color = Palette.pythonBlue.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_PadPainter old) => old.active != active;
}
