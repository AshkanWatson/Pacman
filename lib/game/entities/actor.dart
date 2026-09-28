import 'dart:math' as math;

import '../core/direction.dart';
import '../core/tile.dart';

/// Anything that moves through the maze.
///
/// Positions are in tile units and refer to the actor's centre; the centre
/// of tile (c, r) is (c + 0.5, r + 0.5).
abstract class Actor {
  Actor({required this.x, required this.y, this.dir = Direction.left});

  double x;
  double y;
  Direction dir;

  Tile get tile => Tile(x.floor(), y.floor());

  /// Signed distance from the actor to the centre of its current tile,
  /// measured along [dir]: positive when the centre is still ahead,
  /// negative when it has already been passed.
  double distanceToCenterAlong(Direction d) {
    final t = tile;
    return (t.col + 0.5 - x) * d.dx + (t.row + 0.5 - y) * d.dy;
  }

  void snapToTileCenter() {
    final t = tile;
    x = t.col + 0.5;
    y = t.row + 0.5;
  }

  void placeAt(double nx, double ny, Direction d) {
    x = nx;
    y = ny;
    dir = d;
  }

  /// Keeps the actor inside the horizontal wrap range of the tunnel.
  void wrapHorizontally(int mazeWidth) {
    if (x < -1) x += mazeWidth;
    if (x >= mazeWidth + 1) x -= mazeWidth;
  }

  double distanceTo(Actor other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
