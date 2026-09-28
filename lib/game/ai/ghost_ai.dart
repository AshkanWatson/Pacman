import 'dart:math';

import '../core/direction.dart';
import '../core/maze.dart';
import '../core/tile.dart';
import '../entities/js_ghost.dart';

/// Arcade ghost targeting and steering.
///
/// All logic follows the behaviour documented for the original arcade:
/// ghosts only look one tile ahead, never voluntarily reverse, choose the
/// neighbour closest (euclidean) to a target tile, and break ties in the
/// order up, left, down, right.
abstract final class GhostAi {
  /// Chase-mode target tile for [kind].
  ///
  /// [playerTile]/[playerDir] describe Python, [blinkyTile] is the position
  /// of `undefined` (needed by `null`), and [selfTile] is the ghost itself
  /// (needed by `==`).
  static Tile chaseTarget(
    GhostKind kind, {
    required Tile playerTile,
    required Direction playerDir,
    required Tile blinkyTile,
    required Tile selfTile,
  }) {
    switch (kind) {
      case GhostKind.undefined:
        return playerTile;
      case GhostKind.nan:
        return _aheadOf(playerTile, playerDir, 4);
      case GhostKind.nullGhost:
        final pivot = _aheadOf(playerTile, playerDir, 2);
        return Tile(
          pivot.col * 2 - blinkyTile.col,
          pivot.row * 2 - blinkyTile.row,
        );
      case GhostKind.looseEquals:
        return selfTile.distanceSquaredTo(playerTile) > 64
            ? playerTile
            : kind.scatterTarget;
    }
  }

  /// Tiles "ahead" of Python, faithfully including the arcade overflow bug:
  /// when facing up the offset is also applied to the left.
  static Tile _aheadOf(Tile t, Direction d, int n) {
    final ahead = t.step(d, n);
    return d == Direction.up ? ahead.step(Direction.left, n) : ahead;
  }

  /// The directions a ghost at [tile] travelling [current] may take.
  static List<Direction> options(
    Maze maze,
    Tile tile,
    Direction current, {
    bool throughDoor = false,
    bool restrictUp = false,
  }) {
    final result = <Direction>[];
    for (final d in Direction.moving) {
      if (d == current.opposite) continue;
      if (restrictUp && d == Direction.up && maze.isNoUpwardTurnZone(tile)) {
        continue;
      }
      if (maze.isWalkableForGhost(tile.step(d), throughDoor: throughDoor)) {
        result.add(d);
      }
    }
    return result;
  }

  /// Picks the exit from [tile] closest to [target].
  static Direction steerTowards(
    Maze maze,
    Tile tile,
    Direction current,
    Tile target, {
    bool throughDoor = false,
    bool restrictUp = true,
  }) {
    final opts = options(
      maze,
      tile,
      current,
      throughDoor: throughDoor,
      restrictUp: restrictUp,
    );
    if (opts.isEmpty) return current.opposite; // dead end: turn around
    var best = opts.first;
    var bestDist = tile.step(best).distanceSquaredTo(target);
    for (final d in opts.skip(1)) {
      final dist = tile.step(d).distanceSquaredTo(target);
      if (dist < bestDist) {
        best = d;
        bestDist = dist;
      }
    }
    return best;
  }

  /// Frightened (TypeScript) ghosts pick a pseudo-random direction; if it
  /// is blocked they try the others in up, left, down, right order.
  static Direction wander(
    Maze maze,
    Tile tile,
    Direction current,
    Random random,
  ) {
    final opts = options(maze, tile, current);
    if (opts.isEmpty) return current.opposite;
    final start = random.nextInt(Direction.moving.length);
    for (var i = 0; i < Direction.moving.length; i++) {
      final d = Direction.moving[(start + i) % Direction.moving.length];
      if (opts.contains(d)) return d;
    }
    return opts.first;
  }
}
