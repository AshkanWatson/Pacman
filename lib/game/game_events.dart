import 'core/level_config.dart';
import 'entities/js_ghost.dart';

/// Things that happen during play. The engine queues them; the UI drains
/// them each frame to trigger sounds, messages and achievements.
sealed class GameEvent {
  const GameEvent();
}

class LevelStarted extends GameEvent {
  const LevelStarted(this.level, {required this.firstOfGame});
  final int level;
  final bool firstOfGame;
}

class SemicolonEaten extends GameEvent {
  const SemicolonEaten(this.remaining);
  final int remaining;
}

class PowerBraceEaten extends GameEvent {
  const PowerBraceEaten();
}

/// Ghosts turned into TypeScript.
class FrightStarted extends GameEvent {
  const FrightStarted(this.seconds);
  final double seconds;
}

class FrightEnded extends GameEvent {
  const FrightEnded();
}

class GhostEaten extends GameEvent {
  const GhostEaten(this.ghost, this.points, this.chain);
  final GhostKind ghost;
  final int points;

  /// 1 for the first ghost of a power-up, up to 4.
  final int chain;
}

class BonusSpawned extends GameEvent {
  const BonusSpawned(this.item);
  final BonusItem item;
}

class BonusEaten extends GameEvent {
  const BonusEaten(this.item);
  final BonusItem item;
}

class BonusExpired extends GameEvent {
  const BonusExpired();
}

class PlayerCaught extends GameEvent {
  const PlayerCaught(this.by);
  final GhostKind by;
}

class DeathAnimationStarted extends GameEvent {
  const DeathAnimationStarted();
}

class LifeLost extends GameEvent {
  const LifeLost(this.livesLeft);
  final int livesLeft;
}

class ExtraLifeAwarded extends GameEvent {
  const ExtraLifeAwarded(this.lives);
  final int lives;
}

class LevelCleared extends GameEvent {
  const LevelCleared(this.level, {required this.deathless});
  final int level;
  final bool deathless;
}

class GameOver extends GameEvent {
  const GameOver(this.score, this.level);
  final int score;
  final int level;
}
