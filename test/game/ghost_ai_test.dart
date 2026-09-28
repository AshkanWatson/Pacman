import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pyman/game/ai/ghost_ai.dart';
import 'package:pyman/game/core/direction.dart';
import 'package:pyman/game/core/maze.dart';
import 'package:pyman/game/core/tile.dart';
import 'package:pyman/game/entities/js_ghost.dart';

void main() {
  const player = Tile(10, 20);
  const blinky = Tile(6, 16);

  Tile chase(GhostKind k, {Direction dir = Direction.left, Tile? self}) =>
      GhostAi.chaseTarget(
        k,
        playerTile: player,
        playerDir: dir,
        blinkyTile: blinky,
        selfTile: self ?? const Tile(1, 1),
      );

  group('chase targets', () {
    test('undefined (Blinky) targets Python directly', () {
      expect(chase(GhostKind.undefined), player);
    });

    test('NaN (Pinky) targets four tiles ahead', () {
      expect(chase(GhostKind.nan, dir: Direction.right), const Tile(14, 20));
      expect(chase(GhostKind.nan, dir: Direction.down), const Tile(10, 24));
    });

    test('NaN reproduces the arcade "up" overflow bug', () {
      expect(chase(GhostKind.nan, dir: Direction.up), const Tile(6, 16));
    });

    test('null (Inky) doubles the vector from undefined', () {
      // Pivot = 2 ahead (right) = (12, 20); vector from blinky (6,16) is
      // (6, 4); doubled from blinky -> (18, 24).
      expect(
        chase(GhostKind.nullGhost, dir: Direction.right),
        const Tile(18, 24),
      );
    });

    test('== (Clyde) chases from afar but retreats when close', () {
      expect(chase(GhostKind.looseEquals, self: const Tile(1, 1)), player);
      expect(
        chase(GhostKind.looseEquals, self: const Tile(12, 21)),
        GhostKind.looseEquals.scatterTarget,
      );
    });

    test('scatter corners are distinct and outside the maze', () {
      final corners = GhostKind.values.map((k) => k.scatterTarget).toSet();
      expect(corners.length, 4);
    });
  });

  group('steering', () {
    final maze = Maze();

    test('never reverses voluntarily', () {
      // At (6, 5) moving right, target far to the left.
      final d = GhostAi.steerTowards(
        maze,
        const Tile(6, 5),
        Direction.right,
        const Tile(0, 5),
      );
      expect(d, isNot(Direction.left));
    });

    test('chooses the neighbour closest to the target', () {
      // Intersection (6, 5): exits up, down, left, right.
      final d = GhostAi.steerTowards(
        maze,
        const Tile(6, 5),
        Direction.left,
        const Tile(6, 30),
      );
      expect(d, Direction.down);
    });

    test('breaks ties in up, left, down, right order', () {
      // Target equidistant from up (6,4) and left (5,5) neighbours.
      final d = GhostAi.steerTowards(
        maze,
        const Tile(6, 5),
        Direction.left,
        const Tile(5, 4),
      );
      expect(d, Direction.up);
    });

    test('cannot turn up in the restricted zones', () {
      final opts = GhostAi.options(
        maze,
        const Tile(12, 11),
        Direction.right,
        restrictUp: true,
      );
      expect(opts, isNot(contains(Direction.up)));
    });

    test('only turns around at a dead end', () {
      final d = GhostAi.steerTowards(
        maze,
        const Tile(1, 1),
        Direction.up,
        const Tile(0, 0),
      );
      expect(d, isNot(Direction.down));
    });

    test('frightened wandering only picks legal moves', () {
      final rng = Random(1);
      for (var i = 0; i < 200; i++) {
        final d = GhostAi.wander(maze, const Tile(6, 5), Direction.left, rng);
        expect(d, isNot(Direction.right));
        expect(maze.isWalkableForGhost(const Tile(6, 5).step(d)), isTrue);
      }
    });
  });
}
