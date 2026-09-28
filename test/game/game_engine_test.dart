import 'package:flutter_test/flutter_test.dart';
import 'package:pyman/game/game_engine.dart';

/// Runs the engine until [until] holds or [maxSeconds] elapse.
void runUntil(GameEngine e, bool Function() until, {double maxSeconds = 30}) {
  final steps = (maxSeconds / GameEngine.stepSeconds).ceil();
  for (var i = 0; i < steps; i++) {
    if (until()) return;
    e.step();
  }
  fail('Condition not met within $maxSeconds s');
}

void skipReady(GameEngine e) => runUntil(e, () => e.phase == GamePhase.playing);

/// Freezes every ghost inside the house so tests can focus on Python.
void parkGhosts(GameEngine e) {
  for (final g in e.ghosts) {
    g.state = GhostState.inHouse;
    g.placeAt(g.homeX, JsGhost.houseY, Direction.up);
  }
}

void main() {
  group('start of game', () {
    test('initial state', () {
      final e = GameEngine(seed: 1);
      expect(e.score, 0);
      expect(e.lives, 3);
      expect(e.level, 1);
      expect(e.phase, GamePhase.ready);
      expect(e.drainEvents().first, isA<LevelStarted>());
    });

    test('READY lasts longer on the first life then play begins', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      expect(e.clock, closeTo(GameEngine.firstReadySeconds, 0.02));
    });
  });

  group('Python movement', () {
    test('moves left from the start and eats semicolons', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      parkGhosts(e);
      final x0 = e.player.x;
      runUntil(e, () => e.score >= 20, maxSeconds: 3);
      expect(e.player.x, lessThan(x0));
      expect(e.player.dir, Direction.left);
      expect(e.maze.remaining, lessThan(244));
    });

    test('stops at a wall', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      parkGhosts(e);
      e.player.placeAt(1.5, 1.5, Direction.up);
      e.player.desired = Direction.up;
      for (var i = 0; i < 60; i++) {
        e.step();
        for (final g in e.ghosts) {
          g.state = GhostState.inHouse;
        }
      }
      expect(e.player.y, 1.5);
      expect(e.player.moving, isFalse);
    });

    test('buffers a turn until the next intersection', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      parkGhosts(e);
      // Row 5 corridor; the next opening downward from (4,5)-> (6,5).
      e.player.placeAt(3.5, 5.5, Direction.right);
      e.player.desired = Direction.right;
      e.steer(Direction.down);
      runUntil(e, () => e.player.dir == Direction.down, maxSeconds: 2);
      expect(e.player.tile.col, anyOf(1, 6));
    });

    test('can reverse instantly', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      parkGhosts(e);
      e.step();
      e.steer(Direction.right);
      e.step();
      expect(e.player.dir, Direction.right);
    });

    test('wraps through the tunnel', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      parkGhosts(e);
      e.player.placeAt(1.5, 14.5, Direction.left);
      e.player.desired = Direction.left;
      runUntil(e, () => e.player.x > 20, maxSeconds: 3);
      expect(e.player.tile.row, 14);
    });
  });

  group('scoring and collectibles', () {
    test('semicolon is worth 10 and power brace 50', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      parkGhosts(e);
      e.player.placeAt(1.5, 4.5, Direction.up);
      e.player.desired = Direction.up;
      final before = e.score;
      // (1,4) semicolon under Python first, then (1,3) power brace.
      runUntil(e, () => e.isFrightened, maxSeconds: 2);
      expect(e.score - before, 60);
      final events = e.drainEvents();
      expect(events.whereType<PowerBraceEaten>(), hasLength(1));
      expect(events.whereType<FrightStarted>(), hasLength(1));
    });

    test('power brace converts ghosts to TypeScript and it wears off', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      e.player.placeAt(1.5, 3.5, Direction.up);
      e.step();
      expect(e.isFrightened, isTrue);
      expect(e.ghosts.every((g) => g.frightened), isTrue);
      runUntil(e, () => !e.isFrightened, maxSeconds: 12);
      expect(e.ghosts.any((g) => g.frightened), isFalse);
    });

    test('eating ghosts in one power-up scores 200/400/800/1600', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      e.player.placeAt(1.5, 3.5, Direction.up);
      e.step();
      final points = <int>[];
      for (final g in e.ghosts) {
        g.state = GhostState.active;
        g.frightened = true;
        g.placeAt(e.player.x, e.player.y, Direction.up);
        final before = e.score;
        e.step();
        points.add(e.score - before);
        expect(e.phase, GamePhase.ghostEaten);
        expect(g.state, GhostState.eaten);
        runUntil(e, () => e.phase == GamePhase.playing, maxSeconds: 2);
        // Move eyes away so they don't interfere.
        g.state = GhostState.inHouse;
      }
      expect(points, [200, 400, 800, 1600]);
    });

    test('bonus bracket appears after 70 semicolons and can be eaten', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      parkGhosts(e);
      // Eat 69 collectibles directly, then one more by walking.
      var taken = 0;
      for (var r = 0; r < e.maze.height && taken < 69; r++) {
        for (var c = 0; c < e.maze.width && taken < 69; c++) {
          if (r == 23) continue;
          if (e.maze.itemAt(Tile(c, r)) == Collectible.semicolon) {
            e.maze.take(Tile(c, r));
            taken++;
          }
        }
      }
      runUntil(e, () => e.bonusVisible, maxSeconds: 2);
      expect(e.drainEvents().whereType<BonusSpawned>(), hasLength(1));
      e.player.placeAt(GameEngine.bonusX, GameEngine.bonusY, Direction.left);
      final before = e.score;
      e.step();
      expect(e.score - before, BonusItem.emptyObject.points);
      expect(e.bonusVisible, isFalse);
      expect(e.drainEvents().whereType<BonusEaten>(), hasLength(1));
    });

    test('extra life at 10,000 points, only once', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      parkGhosts(e);
      e.score = 9995;
      runUntil(e, () => e.score >= 10000, maxSeconds: 2);
      expect(e.lives, 4);
      e.score = 19995;
      runUntil(e, () => e.score >= 20000, maxSeconds: 2);
      expect(e.lives, 4);
    });
  });

  group('lives and death', () {
    test('touching a JavaScript ghost costs a life', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      final g = e.ghost(GhostKind.undefined);
      g.placeAt(e.player.x, e.player.y, Direction.left);
      e.step();
      expect(e.phase, GamePhase.dying);
      runUntil(e, () => e.phase == GamePhase.ready, maxSeconds: 4);
      expect(e.lives, 2);
      expect(e.player.x, PythonPlayer.startX);
      final events = e.drainEvents();
      expect(events.whereType<PlayerCaught>(), hasLength(1));
      expect(events.whereType<LifeLost>().single.livesLeft, 2);
    });

    test('game over after the last life', () {
      final e = GameEngine(seed: 1, startingLives: 1);
      skipReady(e);
      final g = e.ghost(GhostKind.undefined);
      g.placeAt(e.player.x, e.player.y, Direction.left);
      e.step();
      runUntil(e, () => e.phase == GamePhase.gameOver, maxSeconds: 4);
      expect(e.lives, 0);
      expect(e.drainEvents().whereType<GameOver>(), hasLength(1));
      final clock = e.clock;
      e.update(1);
      expect(e.clock, clock, reason: 'simulation halts after game over');
    });

    test('restart resets score, lives and level', () {
      final e = GameEngine(seed: 1);
      e.score = 1234;
      e.lives = 1;
      e.level = 3;
      e.restart();
      expect(e.score, 0);
      expect(e.lives, 3);
      expect(e.level, 1);
      expect(e.maze.remaining, 244);
    });
  });

  group('collision detection', () {
    test('overlap uses a half-tile radius', () {
      final e = GameEngine(seed: 1);
      final g = e.ghost(GhostKind.undefined);
      e.player.placeAt(10.5, 5.5, Direction.left);
      g.placeAt(10.9, 5.5, Direction.left);
      expect(GameEngine.collides(e.player, g), isTrue);
      g.placeAt(11.1, 5.5, Direction.left);
      expect(GameEngine.collides(e.player, g), isFalse);
    });

    test('ghosts cannot pass through Python head-on', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      parkGhosts(e);
      final g = e.ghost(GhostKind.undefined);
      g.state = GhostState.active;
      // Row 29 has no side exits between columns 2 and 11.
      e.player.placeAt(3.5, 29.5, Direction.right);
      e.player.desired = Direction.right;
      g.placeAt(10.5, 29.5, Direction.left);
      runUntil(e, () => e.phase != GamePhase.playing, maxSeconds: 2);
      expect(e.phase, GamePhase.dying);
    });
  });

  group('level flow', () {
    test('clearing every collectible completes the level', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      parkGhosts(e);
      for (var r = 0; r < e.maze.height; r++) {
        for (var c = 0; c < e.maze.width; c++) {
          if (!(r == 23 && c == 12)) e.maze.take(Tile(c, r));
        }
      }
      expect(e.maze.remaining, 1);
      runUntil(e, () => e.phase == GamePhase.levelComplete, maxSeconds: 2);
      final cleared = e.drainEvents().whereType<LevelCleared>().single;
      expect(cleared.level, 1);
      expect(cleared.deathless, isTrue);
      runUntil(e, () => e.level == 2, maxSeconds: 4);
      expect(e.maze.remaining, 244);
      expect(e.phase, GamePhase.ready);
      expect(e.config.playerSpeed, 0.9);
    });
  });

  group('ghost behaviour', () {
    test('scatter/chase schedule of level 1 and reversal', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      expect(e.isScatter, isTrue);
      final blinky = e.ghost(GhostKind.undefined);
      runUntil(e, () => !e.isScatter, maxSeconds: 7.2);
      // Mode switch flags a reversal that is applied on the next move.
      expect(e.clock - GameEngine.firstReadySeconds, closeTo(7, 0.05));
      expect(blinky.state, GhostState.active);
    });

    test('ghosts are released from the house over time', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      e.step();
      expect(e.ghost(GhostKind.nan).state, isNot(GhostState.inHouse));
      expect(e.ghost(GhostKind.nullGhost).state, GhostState.inHouse);
      // Keep Python still so the 4 s no-dot timer releases the others.
      e.player.placeAt(1.5, 1.5, Direction.up);
      e.player.desired = Direction.up;
      runUntil(
        e,
        () => e.ghost(GhostKind.nullGhost).state != GhostState.inHouse,
        maxSeconds: 5,
      );
    });

    test('released ghosts leave through the door and roam', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      final pinky = e.ghost(GhostKind.nan);
      runUntil(e, () => pinky.state == GhostState.active, maxSeconds: 5);
      expect(pinky.y, lessThanOrEqualTo(JsGhost.doorY));
    });

    test('eaten ghosts return home and respawn', () {
      final e = GameEngine(seed: 1);
      skipReady(e);
      final g = e.ghost(GhostKind.undefined);
      g.placeAt(1.5, 29.5, Direction.right);
      g.state = GhostState.eaten;
      e.player.placeAt(26.5, 1.5, Direction.left);
      runUntil(e, () => g.state == GhostState.leaving, maxSeconds: 10);
      runUntil(e, () => g.state == GhostState.active, maxSeconds: 10);
      expect(g.frightened, isFalse);
    });

    test('ghosts roam without ever entering walls', () {
      final e = GameEngine(seed: 7);
      skipReady(e);
      // Python hides where ghosts can't reach quickly; we only watch ghosts.
      for (var i = 0; i < 120 * 40; i++) {
        e.player.placeAt(1.5, 29.5, Direction.left);
        e.step();
        if (e.phase != GamePhase.playing) break;
        for (final g in e.ghosts.where((g) => g.state == GhostState.active)) {
          expect(
            e.maze.isWall(g.tile),
            isFalse,
            reason: '${g.kind} in wall at ${g.tile}',
          );
        }
      }
    });

    test('Cruise Elroy speeds up undefined when few semicolons remain', () {
      final e = GameEngine(seed: 1);
      expect(e.elroyStage, 0);
      var n = e.maze.remaining - e.config.elroy2Dots;
      for (var r = 0; r < e.maze.height && n > 0; r++) {
        for (var c = 0; c < e.maze.width && n > 0; c++) {
          if (e.maze.take(Tile(c, r)) != Collectible.none) n--;
        }
      }
      expect(e.elroyStage, 2);
    });
  });

  group('pause', () {
    test('update does nothing while paused', () {
      final e = GameEngine(seed: 1);
      e.togglePause();
      e.update(1);
      expect(e.clock, 0);
      e.togglePause();
      for (var i = 0; i < 10; i++) {
        e.update(0.05);
      }
      expect(e.clock, closeTo(0.5, 0.01));
    });
  });
}
