import '../core/direction.dart';
import '../core/tile.dart';
import 'actor.dart';

/// The four JavaScript ghosts. Each keeps its arcade personality, but gets
/// a JavaScript quirk as a nickname.
enum GhostKind {
  /// Blinky — the chaser. Targets Python's tile directly.
  undefined(
    'undefined',
    'Shadow - chases you directly',
    0xFFFF4D4D,
    Tile(25, -3),
  ),

  /// Pinky — the ambusher. Targets four tiles ahead of Python.
  nan('NaN', 'Speedy - ambushes ahead of you', 0xFFFF8AD8, Tile(2, -3)),

  /// Inky — the fickle one. Uses undefined's position to flank you.
  nullGhost(
    'null',
    'Bashful - flanks with undefined',
    0xFF3FE0FF,
    Tile(27, 34),
  ),

  /// Clyde — the feigner. Chases from afar, retreats up close.
  looseEquals(
    '==',
    'Pokey - loosely equal to chasing',
    0xFFFFB347,
    Tile(0, 34),
  );

  const GhostKind(this.label, this.blurb, this.color, this.scatterTarget);

  final String label;
  final String blurb;
  final int color;

  /// Corner each ghost heads to while scattering (outside the maze, like
  /// the arcade, so the ghost circles the nearest wall block).
  final Tile scatterTarget;
}

enum GhostState {
  /// Bobbing inside the ghost house, waiting for release.
  inHouse,

  /// Scripted path from the house to the door and out.
  leaving,

  /// Roaming the maze (scatter / chase / frightened).
  active,

  /// Only the eyes are left; racing back home.
  eaten,

  /// Eyes entering the house to respawn.
  entering,
}

class JsGhost extends Actor {
  JsGhost(this.kind) : super(x: 0, y: 0) {
    reset();
  }

  final GhostKind kind;

  GhostState state = GhostState.inHouse;

  /// Converted to TypeScript by a power brace: slow, blue and edible.
  bool frightened = false;

  /// Set when the scatter/chase mode flips; the ghost turns around.
  bool reversePending = false;

  /// Personal dot counter used for releasing the ghost from the house.
  int dotCounter = 0;

  /// Last tile a steering decision was made on, so a ghost decides only
  /// once per tile even if it sits on the centre for several steps.
  Tile? lastDecisionTile;

  static const double doorX = 14.0;
  static const double doorY = 11.5;
  static const double houseY = 14.5;

  double get homeX => switch (kind) {
    GhostKind.undefined || GhostKind.nan => 14.0,
    GhostKind.nullGhost => 12.0,
    GhostKind.looseEquals => 16.0,
  };

  bool get isOutside => state == GhostState.active;

  bool get isEyes => state == GhostState.eaten || state == GhostState.entering;

  void reset() {
    frightened = false;
    reversePending = false;
    lastDecisionTile = null;
    if (kind == GhostKind.undefined) {
      placeAt(doorX, doorY, Direction.left);
      state = GhostState.active;
    } else {
      placeAt(
        homeX,
        houseY,
        kind == GhostKind.nan ? Direction.down : Direction.up,
      );
      state = GhostState.inHouse;
    }
  }
}
