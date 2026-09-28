import 'direction.dart';
import 'tile.dart';

/// Static cell types of the maze.
enum Cell { wall, path, door }

/// What is lying on a path cell.
enum Collectible { none, semicolon, powerBrace }

/// The classic 28x31 arcade maze.
///
/// Legend: `#` wall, `.` semicolon (pellet), `o` power brace `{ }`
/// (energizer), `-` ghost-house door, space = empty path.
const List<String> classicMazeLayout = [
  '############################',
  '#............##............#',
  '#.####.#####.##.#####.####.#',
  '#o####.#####.##.#####.####o#',
  '#.####.#####.##.#####.####.#',
  '#..........................#',
  '#.####.##.########.##.####.#',
  '#.####.##.########.##.####.#',
  '#......##....##....##......#',
  '######.##### ## #####.######',
  '######.##### ## #####.######',
  '######.##          ##.######',
  '######.## ###--### ##.######',
  '######.## #      # ##.######',
  '      .   #      #   .      ',
  '######.## #      # ##.######',
  '######.## ######## ##.######',
  '######.##          ##.######',
  '######.## ######## ##.######',
  '######.## ######## ##.######',
  '#............##............#',
  '#.####.#####.##.#####.####.#',
  '#.####.#####.##.#####.####.#',
  '#o..##.......  .......##..o#',
  '###.##.##.########.##.##.###',
  '###.##.##.########.##.##.###',
  '#......##....##....##......#',
  '#.##########.##.##########.#',
  '#.##########.##.##########.#',
  '#..........................#',
  '############################',
];

/// Maze geometry plus the mutable collectible state for the current level.
class Maze {
  Maze([List<String> layout = classicMazeLayout])
    : width = layout.first.length,
      height = layout.length,
      _layout = List.unmodifiable(layout) {
    for (final row in layout) {
      if (row.length != width) {
        throw ArgumentError('All maze rows must have the same width.');
      }
    }
    _cells = List<Cell>.filled(width * height, Cell.wall);
    powerBraceTiles = List.unmodifiable([
      for (var r = 0; r < height; r++)
        for (var c = 0; c < width; c++)
          if (layout[r][c] == 'o') Tile(c, r),
    ]);
    _items = List<Collectible>.filled(width * height, Collectible.none);
    for (var r = 0; r < height; r++) {
      for (var c = 0; c < width; c++) {
        _cells[r * width + c] = switch (layout[r][c]) {
          '#' => Cell.wall,
          '-' => Cell.door,
          _ => Cell.path,
        };
      }
    }
    reset();
  }

  final int width;
  final int height;
  final List<String> _layout;
  late final List<Cell> _cells;
  late final List<Collectible> _items;

  /// Where the power braces start each level.
  late final List<Tile> powerBraceTiles;

  int _remaining = 0;
  int _total = 0;

  /// Incremented every time a collectible changes; lets renderers cache.
  int version = 0;

  /// Number of collectibles (semicolons + power braces) left.
  int get remaining => _remaining;

  /// Total collectibles at the start of a level.
  int get total => _total;

  int get eaten => _total - _remaining;

  /// Restores every collectible for a new level.
  void reset() {
    _remaining = 0;
    for (var r = 0; r < height; r++) {
      for (var c = 0; c < width; c++) {
        final item = switch (_layout[r][c]) {
          '.' => Collectible.semicolon,
          'o' => Collectible.powerBrace,
          _ => Collectible.none,
        };
        _items[r * width + c] = item;
        if (item != Collectible.none) _remaining++;
      }
    }
    _total = _remaining;
    version++;
  }

  int _wrapCol(int col) => ((col % width) + width) % width;

  /// Cell type with horizontal wrap-around (the tunnel). Rows outside the
  /// maze are walls.
  Cell cellAt(Tile t) {
    if (t.row < 0 || t.row >= height) return Cell.wall;
    return _cells[t.row * width + _wrapCol(t.col)];
  }

  bool isWall(Tile t) => cellAt(t) == Cell.wall;

  /// Python can only walk on plain path cells.
  bool isWalkableForPlayer(Tile t) => cellAt(t) == Cell.path;

  /// Ghosts may walk paths, and the door only when [throughDoor] is set.
  bool isWalkableForGhost(Tile t, {bool throughDoor = false}) {
    final cell = cellAt(t);
    return cell == Cell.path || (throughDoor && cell == Cell.door);
  }

  Collectible itemAt(Tile t) {
    if (t.row < 0 || t.row >= height) return Collectible.none;
    return _items[t.row * width + _wrapCol(t.col)];
  }

  /// Removes and returns the collectible on [t].
  Collectible take(Tile t) {
    final item = itemAt(t);
    if (item != Collectible.none) {
      _items[t.row * width + _wrapCol(t.col)] = Collectible.none;
      _remaining--;
      version++;
    }
    return item;
  }

  /// Tiles in the side tunnels, where ghosts are slowed down.
  bool isTunnel(Tile t) {
    if (t.row != tunnelRow) return false;
    final c = _wrapCol(t.col);
    return c <= 5 || c >= width - 6;
  }

  /// The four tiles above the ghost house and above Python's start where,
  /// in the arcade, ghosts may not turn upwards while chasing/scattering.
  bool isNoUpwardTurnZone(Tile t) =>
      (t.row == 11 || t.row == 23) && t.col >= 12 && t.col <= 15;

  /// Returns the valid moving directions out of [t] for the player.
  Iterable<Direction> playerExits(Tile t) =>
      Direction.moving.where((d) => isWalkableForPlayer(t.step(d)));

  static const int tunnelRow = 14;
}
