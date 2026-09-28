import '../core/direction.dart';
import 'actor.dart';

/// Python 🐍 — the player-controlled hero (the Pac-Man of this game).
class PythonPlayer extends Actor {
  PythonPlayer() : super(x: startX, y: startY);

  static const double startX = 14.0;
  static const double startY = 23.5;

  /// Buffered input: the direction Python turns into as soon as possible.
  Direction desired = Direction.left;

  /// Whether Python moved during the last simulation step.
  bool moving = false;

  /// Remaining pause after eating (the arcade stops Pac-Man for one frame
  /// per dot and three frames per energizer).
  double stall = 0;

  /// Distance travelled, used to animate the mouth.
  double odometer = 0;

  void reset() {
    placeAt(startX, startY, Direction.left);
    desired = Direction.left;
    moving = false;
    stall = 0;
    odometer = 0;
  }
}
