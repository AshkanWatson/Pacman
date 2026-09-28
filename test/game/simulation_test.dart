import 'dart:collection';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pyman/game/game_engine.dart';

/// Direction of the first step on a shortest path from [from] to the
/// nearest collectible, or null when none is reachable.
Direction? towardsNearestCollectible(Maze maze, Tile from) {
  final start = Tile((from.col + maze.width) % maze.width, from.row);
  final firstStep = <Tile, Direction>{};
  final queue = Queue<Tile>()..add(start);
  final seen = {start};
  while (queue.isNotEmpty) {
    final t = queue.removeFirst();
    if (t != start && maze.itemAt(t) != Collectible.none) return firstStep[t];
    for (final d in Direction.moving) {
      var n = t.step(d);
      n = Tile((n.col + maze.width) % maze.width, n.row);
      if (!maze.isWalkableForPlayer(n) || !seen.add(n)) continue;
      firstStep[n] = t == start ? d : firstStep[t]!;
      queue.add(n);
    }
  }
  return null;
}

void main() {
  test('a bot clears three full levels through real movement', () {
    final e = GameEngine(seed: 3);
    final events = <GameEvent>[];
    var steps = 0;
    while (e.level < 4 && steps < 120 * 60 * 10) {
      // Keep ghosts out of the way: this test is about maze clearing.
      for (final g in e.ghosts) {
        g.state = GhostState.inHouse;
        g.placeAt(g.homeX, JsGhost.houseY, Direction.up);
      }
      if (e.phase == GamePhase.playing) {
        final d = towardsNearestCollectible(e.maze, e.player.tile);
        if (d != null) e.steer(d);
      }
      e.step();
      events.addAll(e.drainEvents());
      steps++;
    }
    expect(e.level, 4);
    expect(events.whereType<LevelCleared>().map((l) => l.level), [1, 2, 3]);
    expect(events.whereType<PowerBraceEaten>(), hasLength(12));
    expect(events.whereType<BonusSpawned>(), hasLength(6));
    expect(events.whereType<SemicolonEaten>(), hasLength(240 * 3));
    // 240 semicolons + 4 braces per level, plus any bonus brackets eaten.
    final bonus = events.whereType<BonusEaten>().fold<int>(
      0,
      (sum, b) => sum + b.item.points,
    );
    expect(e.score, 3 * (240 * 10 + 4 * 50) + bonus);
  });

  for (final seed in [1, 2, 3, 4, 5]) {
    test('random play stays consistent (seed $seed)', () {
      final rng = Random(seed);
      final e = GameEngine(seed: seed, startingLives: 5);
      var steps = 0;
      var lastLives = e.lives;
      final seenPhases = <GamePhase>{};
      while (e.phase != GamePhase.gameOver && steps < 120 * 60 * 15) {
        if (rng.nextDouble() < 0.02) {
          e.steer(Direction.moving[rng.nextInt(4)]);
        }
        if (rng.nextDouble() < 0.001) e.togglePause();
        if (e.paused) {
          e.update(0.05);
          e.togglePause();
        }
        e.step();
        e.drainEvents();
        steps++;
        seenPhases.add(e.phase);

        expect(e.maze.isWalkableForPlayer(e.player.tile), isTrue);
        for (final g in e.ghosts) {
          if (g.state == GhostState.active || g.state == GhostState.eaten) {
            expect(
              e.maze.isWall(g.tile),
              isFalse,
              reason: '${g.kind} ${g.state} in a wall at ${g.tile}',
            );
          }
        }
        expect(e.lives, inInclusiveRange(0, 6));
        expect(e.lives, lessThanOrEqualTo(lastLives + 1));
        lastLives = e.lives;
      }
      expect(seenPhases, contains(GamePhase.playing));
      expect(seenPhases, contains(GamePhase.dying));
    });
  }

  test('eaten ghosts always make it home within a few seconds', () {
    final e = GameEngine(seed: 9);
    runTo(e, () => e.phase == GamePhase.playing);
    for (final start in const [
      Tile(1, 1),
      Tile(26, 29),
      Tile(1, 29),
      Tile(26, 1),
      Tile(0, 14),
    ]) {
      final g = e.ghost(GhostKind.nullGhost);
      g.state = GhostState.eaten;
      g.frightened = false;
      g.lastDecisionTile = null;
      g.placeAt(start.col + 0.5, start.row + 0.5, Direction.right);
      var t = 0;
      while (g.state != GhostState.active && t < 120 * 12) {
        e.player.placeAt(14.0, 23.5, Direction.left); // stay safe
        e.step();
        t++;
      }
      expect(g.state, GhostState.active, reason: 'from $start');
    }
  });
}

void runTo(GameEngine e, bool Function() cond) {
  for (var i = 0; i < 120 * 10 && !cond(); i++) {
    e.step();
  }
}
