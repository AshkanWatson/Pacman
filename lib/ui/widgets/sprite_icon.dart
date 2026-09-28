import 'package:flutter/widgets.dart';

import '../../game/core/direction.dart';
import '../../game/entities/js_ghost.dart';
import '../render/sprites.dart';

final SpriteKit _sharedSprites = SpriteKit();

/// Python drawn as a static icon (lives counter, menus).
class PythonIcon extends StatelessWidget {
  const PythonIcon({super.key, this.size = 20, this.dir = Direction.right});
  final double size;
  final Direction dir;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _SpritePainter((c) {
        _sharedSprites.drawPython(c, 0.9, 0.9, dir, mouth: 0.55);
      }, key: 'python$dir'),
    ),
  );
}

/// A JavaScript (or TypeScript) ghost drawn as a static icon.
class GhostIcon extends StatelessWidget {
  const GhostIcon({
    super.key,
    required this.kind,
    this.size = 24,
    this.typescript = false,
  });
  final GhostKind kind;
  final double size;
  final bool typescript;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _SpritePainter((c) {
        _sharedSprites.drawGhost(
          c,
          0.9,
          0.9,
          kind,
          Direction.right,
          typescript: typescript,
        );
      }, key: '${kind.name}$typescript'),
    ),
  );
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.draw, {this.key = 'python'});
  final void Function(Canvas) draw;
  final String key;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1.8);
    draw(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpritePainter old) => old.key != key;
}
