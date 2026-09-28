import 'dart:math';

import 'ai/ghost_ai.dart';
import 'core/direction.dart';
import 'core/level_config.dart';
import 'core/maze.dart';
import 'core/tile.dart';
import 'entities/js_ghost.dart';
import 'entities/python_player.dart';
import 'game_events.dart';

export 'core/direction.dart';
export 'core/level_config.dart';
export 'core/maze.dart';
export 'core/tile.dart';
export 'entities/js_ghost.dart';
export 'entities/python_player.dart';
export 'game_events.dart';

enum GamePhase {
  /// "READY!" — everything frozen before play starts.
  ready,
  playing,

  /// Short freeze showing the points for a ghost that was just eaten.
  ghostEaten,

  /// Python was caught: freeze, then the "Traceback" death animation.
  dying,

  /// All collectibles gone: the maze flashes before the next level.
  levelComplete,
  gameOver,
}

/// A floating score label.
class ScorePopup {
  ScorePopup(this.x, this.y, this.points, this.remaining);
  final double x;
  final double y;
  final int points;
  double remaining;
}

/// The complete, UI-independent game simulation.
///
/// Time advances in fixed steps of [stepSeconds] so behaviour is identical
/// at any display refresh rate and fully deterministic for a given [seed].
class GameEngine {
  GameEngine({this.startingLives = 3, int? seed, this.extraLifeScore = 10000})
    : _random = Random(seed) {
    _startGame();
  }

  static const double stepSeconds = 1 / 120;
  static const double firstReadySeconds = 4.2;
  static const double readySeconds = 2.0;
  static const double ghostEatenSeconds = 1.0;
  static const double deathFreezeSeconds = 1.0;
  static const double deathAnimationSeconds = 1.6;
  static const double levelCompleteSeconds = 2.6;
  static const double hitRadius = 0.5;
  static const double bonusX = 14.0;
  static const double bonusY = 17.5;

  /// Where eaten ghosts (eyes) head for before entering the house.
  static const Tile houseEntranceTarget = Tile(13, 11);

  final int startingLives;
  final int extraLifeScore;
  final Random _random;

  final Maze maze = Maze();
  final PythonPlayer player = PythonPlayer();
  late final List<JsGhost> ghosts = [
    for (final k in GhostKind.values) JsGhost(k),
  ];

  JsGhost ghost(GhostKind kind) => ghosts[kind.index];

  late LevelConfig config;
  int score = 0;
  int lives = 0;
  int level = 1;
  GamePhase phase = GamePhase.ready;

  /// Seconds spent in the current [phase].
  double phaseTime = 0;

  /// Total simulated seconds, used for idle animations.
  double clock = 0;

  bool paused = false;

  double _accumulator = 0;
  bool _firstReady = true;

  // Scatter/chase schedule.
  int _modeIndex = 0;
  double _modeTime = 0;

  // TypeScript power-up.
  double frightRemaining = 0;
  int _ghostChain = 0;

  // Bonus brackets.
  double bonusRemaining = 0;
  ScorePopup? bonusPopup;
  ScorePopup? ghostPopup;
  GhostKind? justEaten;

  // Ghost-house release bookkeeping.
  bool _globalCounterActive = false;
  int _globalCounter = 0;
  double _sinceLastDot = 0;
  bool _elroyEnabled = true;

  bool _diedThisLevel = false;
  bool _extraLifeAwarded = false;
  bool _deathAnimationAnnounced = false;

  final List<GameEvent> _events = [];

  // ---------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------

  /// Returns and clears the queued events.
  List<GameEvent> drainEvents() {
    if (_events.isEmpty) return const [];
    final out = List<GameEvent>.of(_events);
    _events.clear();
    return out;
  }

  /// Buffers a turn for Python.
  void steer(Direction d) {
    if (d == Direction.none) return;
    player.desired = d;
  }

  void togglePause() => paused = !paused;

  void restart() {
    _events.clear();
    _startGame();
  }

  /// Advances the simulation by real elapsed time [dt] (seconds).
  void update(double dt) {
    if (paused || phase == GamePhase.gameOver) return;
    _accumulator += dt.clamp(0.0, 0.1);
    while (_accumulator >= stepSeconds) {
      _accumulator -= stepSeconds;
      step();
      if (phase == GamePhase.gameOver) {
        _accumulator = 0;
        break;
      }
    }
  }

  bool get isScatter =>
      _modeIndex < config.modeSchedule.length && _modeIndex.isEven;

  bool get isFrightened => frightRemaining > 0;

  /// True while TypeScript is about to wear off.
  bool get frightFlashing =>
      frightRemaining > 0 && frightRemaining <= config.flashWindow;

  /// Whether flashing ghosts are currently drawn in their white frame.
  bool get frightFlashWhite =>
      frightFlashing &&
      (frightRemaining / (LevelConfig.flashCycle / 2)).floor().isOdd;

  bool get bonusVisible => bonusRemaining > 0;

  /// 0..1 progress of the death animation (0 before it starts).
  double get deathProgress {
    if (phase != GamePhase.dying) return 0;
    final t = (phaseTime - deathFreezeSeconds) / deathAnimationSeconds;
    return t.clamp(0.0, 1.0);
  }

  /// Whether the maze should be drawn in its "flash" colour.
  bool get levelFlashOn =>
      phase == GamePhase.levelComplete &&
      phaseTime > 0.6 &&
      ((phaseTime - 0.6) / 0.25).floor().isOdd;

  /// Current Cruise Elroy stage (0, 1 or 2) of `undefined`.
  int get elroyStage {
    if (!_elroyEnabled) return 0;
    final remaining = maze.remaining;
    if (remaining <= config.elroy2Dots) return 2;
    if (remaining <= config.elroy1Dots) return 1;
    return 0;
  }

  int get ghostChain => _ghostChain;

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  void _startGame() {
    score = 0;
    lives = startingLives;
    level = 1;
    paused = false;
    _accumulator = 0;
    clock = 0;
    _firstReady = true;
    _extraLifeAwarded = false;
    _startLevel();
  }

  void _startLevel() {
    config = LevelConfig.forLevel(level);
    maze.reset();
    _globalCounterActive = false;
    _globalCounter = 0;
    _elroyEnabled = true;
    _diedThisLevel = false;
    for (final g in ghosts) {
      g.dotCounter = 0;
    }
    _resetActors();
    _events.add(LevelStarted(level, firstOfGame: _firstReady));
  }

  void _resetActors() {
    player.reset();
    for (final g in ghosts) {
      g.reset();
    }
    _modeIndex = 0;
    _modeTime = 0;
    frightRemaining = 0;
    _ghostChain = 0;
    bonusRemaining = 0;
    bonusPopup = null;
    ghostPopup = null;
    justEaten = null;
    _sinceLastDot = 0;
    _deathAnimationAnnounced = false;
    _setPhase(GamePhase.ready);
  }

  void _setPhase(GamePhase p) {
    phase = p;
    phaseTime = 0;
  }

  /// Advances exactly one fixed simulation step. Public for tests.
  void step() {
    const h = stepSeconds;
    clock += h;
    phaseTime += h;
    _tickPopups(h);

    switch (phase) {
      case GamePhase.ready:
        final limit = _firstReady ? firstReadySeconds : readySeconds;
        if (phaseTime >= limit) {
          _firstReady = false;
          _setPhase(GamePhase.playing);
        }
      case GamePhase.playing:
        _updatePlaying(h);
      case GamePhase.ghostEaten:
        // Other eyes keep moving while the score is shown, as in the arcade.
        for (final g in ghosts) {
          if (g.isEyes && g.kind != justEaten) _moveGhost(g, h);
        }
        if (phaseTime >= ghostEatenSeconds) {
          justEaten = null;
          ghostPopup = null;
          _setPhase(GamePhase.playing);
        }
      case GamePhase.dying:
        if (!_deathAnimationAnnounced && phaseTime >= deathFreezeSeconds) {
          _deathAnimationAnnounced = true;
          _events.add(const DeathAnimationStarted());
        }
        if (phaseTime >= deathFreezeSeconds + deathAnimationSeconds) {
          _loseLife();
        }
      case GamePhase.levelComplete:
        if (phaseTime >= levelCompleteSeconds) {
          level++;
          _startLevel();
        }
      case GamePhase.gameOver:
        break;
    }
  }

  void _tickPopups(double h) {
    final bp = bonusPopup;
    if (bp != null) {
      bp.remaining -= h;
      if (bp.remaining <= 0) bonusPopup = null;
    }
  }

  void _loseLife() {
    lives--;
    _diedThisLevel = true;
    _events.add(LifeLost(lives));
    if (lives <= 0) {
      lives = 0;
      _setPhase(GamePhase.gameOver);
      _events.add(GameOver(score, level));
      return;
    }
    // Arcade: after a death a global dot counter releases the ghosts and
    // Cruise Elroy is suspended until the last ghost leaves the house.
    _globalCounterActive = true;
    _globalCounter = 0;
    _elroyEnabled = false;
    _resetActors();
  }

  // ---------------------------------------------------------------------
  // Playing
  // ---------------------------------------------------------------------

  void _updatePlaying(double h) {
    _updateTimers(h);
    _updateHouse();

    _movePlayer(h);
    if (phase != GamePhase.playing) return;
    if (_checkCollisions()) return;

    for (final g in ghosts) {
      _moveGhost(g, h);
    }
    _checkCollisions();
  }

  void _updateTimers(double h) {
    if (frightRemaining > 0) {
      frightRemaining -= h;
      if (frightRemaining <= 0) _endFright();
    } else if (_modeIndex < config.modeSchedule.length) {
      _modeTime += h;
      if (_modeTime >= config.modeSchedule[_modeIndex]) {
        _modeTime = 0;
        _modeIndex++;
        for (final g in ghosts) {
          if (g.state == GhostState.active) g.reversePending = true;
        }
      }
    }

    if (bonusRemaining > 0) {
      bonusRemaining -= h;
      if (bonusRemaining <= 0) {
        bonusRemaining = 0;
        _events.add(const BonusExpired());
      }
    }
    _sinceLastDot += h;
  }

  void _endFright() {
    frightRemaining = 0;
    for (final g in ghosts) {
      g.frightened = false;
    }
    _events.add(const FrightEnded());
  }

  // ------------------------------ Player -------------------------------

  void _movePlayer(double h) {
    final p = player;
    if (p.stall > 0) {
      p.stall -= h;
      p.moving = false;
      _checkBonus();
      return;
    }
    final factor = isFrightened ? config.playerFrightSpeed : config.playerSpeed;
    final moved = _advancePlayer(factor * LevelConfig.baseTilesPerSecond * h);
    p.moving = moved > 0;
    p.odometer += moved;
    _eatAt(p.tile);
    _checkBonus();
  }

  /// Moves Python up to [distance] tiles, handling buffered turns,
  /// cornering, walls and the tunnel. Returns the distance moved.
  double _advancePlayer(double distance) {
    final p = player;
    var remaining = distance;
    var moved = 0.0;
    const eps = 1e-6;

    if (p.desired == p.dir.opposite) p.dir = p.desired;

    // Cornering: a turn pressed just after passing a tile centre is still
    // honoured, which keeps the controls feeling responsive.
    final ahead0 = p.distanceToCenterAlong(p.dir);
    if (p.desired != Direction.none &&
        ahead0 < 0 &&
        ahead0 > -0.3 &&
        !p.desired.isParallelTo(p.dir) &&
        maze.isWalkableForPlayer(p.tile.step(p.desired))) {
      p.snapToTileCenter();
      p.dir = p.desired;
    }

    var guard = 0;
    while (remaining > eps && guard++ < 16) {
      final t = p.tile;
      final ahead = p.distanceToCenterAlong(p.dir);
      double leg;
      if (ahead.abs() <= eps) {
        p.snapToTileCenter();
        if (p.desired != Direction.none &&
            maze.isWalkableForPlayer(t.step(p.desired))) {
          p.dir = p.desired;
        }
        if (!maze.isWalkableForPlayer(t.step(p.dir))) break;
        leg = 1.0;
      } else if (ahead > 0) {
        leg = ahead;
      } else {
        leg = 1 + ahead;
      }
      final m = min(remaining, leg);
      p.x += p.dir.dx * m;
      p.y += p.dir.dy * m;
      p.wrapHorizontally(maze.width);
      remaining -= m;
      moved += m;
    }
    return moved;
  }

  void _eatAt(Tile t) {
    switch (maze.take(t)) {
      case Collectible.none:
        return;
      case Collectible.semicolon:
        _addScore(10);
        player.stall = 1 / 60;
        _events.add(SemicolonEaten(maze.remaining));
      case Collectible.powerBrace:
        _addScore(50);
        player.stall = 3 / 60;
        _events.add(const PowerBraceEaten());
        _startFright();
    }
    _onDotEaten();
    if (maze.remaining == 0) {
      if (frightRemaining > 0) _endFright();
      bonusRemaining = 0;
      _setPhase(GamePhase.levelComplete);
      _events.add(LevelCleared(level, deathless: !_diedThisLevel));
    } else if (maze.eaten == 70 || maze.eaten == 170) {
      bonusRemaining = 9 + _random.nextDouble();
      _events.add(BonusSpawned(config.bonus));
    }
  }

  void _startFright() {
    _ghostChain = 0;
    for (final g in ghosts) {
      if (g.state == GhostState.active) g.reversePending = true;
    }
    if (config.frightSeconds <= 0) return;
    frightRemaining = config.frightSeconds;
    for (final g in ghosts) {
      if (!g.isEyes) g.frightened = true;
    }
    _events.add(FrightStarted(config.frightSeconds));
  }

  void _checkBonus() {
    if (bonusRemaining <= 0) return;
    if ((player.x - bonusX).abs() < 0.75 && (player.y - bonusY).abs() < 0.5) {
      final item = config.bonus;
      bonusRemaining = 0;
      _addScore(item.points);
      bonusPopup = ScorePopup(bonusX, bonusY, item.points, 2.0);
      _events.add(BonusEaten(item));
    }
  }

  void _addScore(int points) {
    score += points;
    if (!_extraLifeAwarded && extraLifeScore > 0 && score >= extraLifeScore) {
      _extraLifeAwarded = true;
      lives++;
      _events.add(ExtraLifeAwarded(lives));
    }
  }

  // ---------------------------------------------------------------------
  // Ghost house
  // ---------------------------------------------------------------------

  static const _houseOrder = [
    GhostKind.nan,
    GhostKind.nullGhost,
    GhostKind.looseEquals,
  ];

  JsGhost? get _preferredWaiting {
    for (final k in _houseOrder) {
      final g = ghost(k);
      if (g.state == GhostState.inHouse) return g;
    }
    return null;
  }

  int _personalLimit(GhostKind kind) => switch ((level, kind)) {
    (1, GhostKind.nullGhost) => 30,
    (1, GhostKind.looseEquals) => 60,
    (2, GhostKind.looseEquals) => 50,
    _ => 0,
  };

  void _onDotEaten() {
    _sinceLastDot = 0;
    if (_globalCounterActive) {
      _globalCounter++;
      final pinky = ghost(GhostKind.nan);
      final inky = ghost(GhostKind.nullGhost);
      final clyde = ghost(GhostKind.looseEquals);
      if (_globalCounter == 7 && pinky.state == GhostState.inHouse) {
        _release(pinky);
      } else if (_globalCounter == 17 && inky.state == GhostState.inHouse) {
        _release(inky);
      } else if (_globalCounter == 32 && clyde.state == GhostState.inHouse) {
        _release(clyde);
        _globalCounterActive = false;
        _globalCounter = 0;
      }
    } else {
      _preferredWaiting?.dotCounter++;
    }
  }

  void _updateHouse() {
    final waiting = _preferredWaiting;
    if (waiting == null) return;
    if (!_globalCounterActive &&
        waiting.dotCounter >= _personalLimit(waiting.kind)) {
      _release(waiting);
      return;
    }
    final limit = level >= 5 ? 3.0 : 4.0;
    if (_sinceLastDot >= limit) {
      _sinceLastDot = 0;
      _release(waiting);
    }
  }

  void _release(JsGhost g) {
    g.state = GhostState.leaving;
    if (g.kind == GhostKind.looseEquals) _elroyEnabled = true;
  }

  // ---------------------------------------------------------------------
  // Ghost movement
  // ---------------------------------------------------------------------

  double _ghostSpeedFactor(JsGhost g) {
    switch (g.state) {
      case GhostState.inHouse:
      case GhostState.leaving:
        return 0.5;
      case GhostState.eaten:
      case GhostState.entering:
        return 2.0;
      case GhostState.active:
        if (maze.isTunnel(g.tile)) return config.ghostTunnelSpeed;
        if (g.frightened) return config.ghostFrightSpeed;
        if (g.kind == GhostKind.undefined) {
          final stage = elroyStage;
          if (stage == 2) return config.elroy2Speed;
          if (stage == 1) return config.elroy1Speed;
        }
        return config.ghostSpeed;
    }
  }

  void _moveGhost(JsGhost g, double h) {
    var dist = _ghostSpeedFactor(g) * LevelConfig.baseTilesPerSecond * h;
    switch (g.state) {
      case GhostState.inHouse:
        _bob(g, dist);
      case GhostState.leaving:
        dist = _scriptTo(g, JsGhost.doorX, JsGhost.houseY, dist, xFirst: true);
        dist = _scriptTo(g, JsGhost.doorX, JsGhost.doorY, dist, xFirst: false);
        if (g.x == JsGhost.doorX && g.y == JsGhost.doorY) {
          g.state = GhostState.active;
          g.dir = Direction.left;
          g.lastDecisionTile = null;
          g.reversePending = false;
          if (dist > 0) _roam(g, dist);
        }
      case GhostState.entering:
        dist = _scriptTo(g, JsGhost.doorX, JsGhost.doorY, dist, xFirst: true);
        dist = _scriptTo(g, JsGhost.doorX, JsGhost.houseY, dist, xFirst: false);
        if (g.x == JsGhost.doorX && g.y == JsGhost.houseY) {
          g.state = GhostState.leaving; // revived as fresh JavaScript
          g.frightened = false;
        }
      case GhostState.eaten:
        _roam(g, dist);
        if (_atHouseEntrance(g)) g.state = GhostState.entering;
      case GhostState.active:
        _roam(g, dist);
    }
  }

  void _bob(JsGhost g, double dist) {
    const top = JsGhost.houseY - 0.5;
    const bottom = JsGhost.houseY + 0.5;
    if (g.dir != Direction.up && g.dir != Direction.down) g.dir = Direction.up;
    g.y += g.dir.dy * dist;
    if (g.y <= top) {
      g.y = top;
      g.dir = Direction.down;
    } else if (g.y >= bottom) {
      g.y = bottom;
      g.dir = Direction.up;
    }
  }

  /// Moves [g] toward (tx, ty) along one axis ([xFirst] picks which axis
  /// is resolved in this call). Returns the unused distance.
  double _scriptTo(
    JsGhost g,
    double tx,
    double ty,
    double dist, {
    required bool xFirst,
  }) {
    if (dist <= 0) return 0;
    if (xFirst) {
      final dx = tx - g.x;
      if (dx.abs() > 1e-9) {
        final m = min(dist, dx.abs());
        g.dir = dx > 0 ? Direction.right : Direction.left;
        g.x += dx.sign * m;
        if ((tx - g.x).abs() < 1e-9) g.x = tx;
        return dist - m;
      }
      g.x = tx;
      return dist;
    }
    if ((g.x - tx).abs() > 1e-9) return 0; // x not aligned yet
    final dy = ty - g.y;
    if (dy.abs() > 1e-9) {
      final m = min(dist, dy.abs());
      g.dir = dy > 0 ? Direction.down : Direction.up;
      g.y += dy.sign * m;
      if ((ty - g.y).abs() < 1e-9) g.y = ty;
      return dist - m;
    }
    g.y = ty;
    return dist;
  }

  /// Free movement through the maze with a decision at every tile centre.
  void _roam(JsGhost g, double distance) {
    var remaining = distance;
    const eps = 1e-6;
    var guard = 0;
    while (remaining > eps && guard++ < 16) {
      if (g.reversePending) {
        g.reversePending = false;
        g.dir = g.dir.opposite;
        g.lastDecisionTile = null;
      }
      final t = g.tile;
      final ahead = g.distanceToCenterAlong(g.dir);
      double leg;
      if (ahead.abs() <= eps && g.lastDecisionTile != t) {
        g.snapToTileCenter();
        g.dir = _decide(g, t);
        g.lastDecisionTile = t;
        leg = 1.0;
      } else if (ahead > eps) {
        leg = ahead;
      } else {
        leg = 1 + ahead;
        if (leg <= eps) leg = 1.0;
      }
      final m = min(remaining, leg);
      g.x += g.dir.dx * m;
      g.y += g.dir.dy * m;
      g.wrapHorizontally(maze.width);
      remaining -= m;
      if (g.state == GhostState.eaten && _atHouseEntrance(g)) return;
    }
  }

  bool _atHouseEntrance(JsGhost g) {
    final t = g.tile;
    return t.row == houseEntranceTarget.row && (t.col == 13 || t.col == 14);
  }

  Direction _decide(JsGhost g, Tile t) {
    if (g.state == GhostState.eaten) {
      return GhostAi.steerTowards(
        maze,
        t,
        g.dir,
        houseEntranceTarget,
        restrictUp: false,
      );
    }
    if (g.frightened) return GhostAi.wander(maze, t, g.dir, _random);
    return GhostAi.steerTowards(maze, t, g.dir, targetFor(g));
  }

  /// The tile [g] is currently heading for (scatter corner or chase target).
  Tile targetFor(JsGhost g) {
    final elroyChases = g.kind == GhostKind.undefined && elroyStage > 0;
    if (isScatter && !elroyChases) return g.kind.scatterTarget;
    return GhostAi.chaseTarget(
      g.kind,
      playerTile: player.tile,
      playerDir: player.dir,
      blinkyTile: ghost(GhostKind.undefined).tile,
      selfTile: g.tile,
    );
  }

  // ---------------------------------------------------------------------
  // Collisions
  // ---------------------------------------------------------------------

  /// Returns true when a collision changed the phase.
  bool _checkCollisions() {
    for (final g in ghosts) {
      if (g.state != GhostState.active) continue;
      if (!collides(player, g)) continue;
      if (g.frightened) {
        _eatGhost(g);
      } else {
        _catchPlayer(g);
      }
      return true;
    }
    return false;
  }

  /// Whether Python and a ghost overlap.
  static bool collides(PythonPlayer p, JsGhost g) =>
      p.distanceTo(g) < hitRadius;

  void _eatGhost(JsGhost g) {
    _ghostChain = min(_ghostChain + 1, 4);
    final points = 200 << (_ghostChain - 1);
    _addScore(points);
    g.state = GhostState.eaten;
    g.frightened = false;
    g.lastDecisionTile = null;
    g.reversePending = false;
    justEaten = g.kind;
    ghostPopup = ScorePopup(g.x, g.y, points, ghostEatenSeconds);
    _setPhase(GamePhase.ghostEaten);
    _events.add(GhostEaten(g.kind, points, _ghostChain));
  }

  void _catchPlayer(JsGhost g) {
    bonusRemaining = 0;
    _setPhase(GamePhase.dying);
    _deathAnimationAnnounced = false;
    _events.add(PlayerCaught(g.kind));
  }
}
